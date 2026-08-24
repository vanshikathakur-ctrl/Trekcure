import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "jsr:@supabase/supabase-js@2";

import { SignJWT, importPKCS8 } from "npm:jose@5";

// ============================================================
// SUPABASE CONFIGURATION
// ============================================================

const supabaseUrl = Deno.env.get("SUPABASE_URL");

const supabaseServiceRoleKey =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error(
    "Missing Supabase environment variables",
  );
}

const supabase = createClient(
  supabaseUrl,
  supabaseServiceRoleKey,
);

// ============================================================
// GET FIREBASE ACCESS TOKEN
// ============================================================

async function getFirebaseAccessToken() {
  const projectId =
    Deno.env.get("FIREBASE_PROJECT_ID");

  const clientEmail =
    Deno.env.get("FIREBASE_CLIENT_EMAIL");

  const privateKey = Deno.env
    .get("FIREBASE_PRIVATE_KEY")
    ?.replace(/\\n/g, "\n");

  if (
    !projectId ||
    !clientEmail ||
    !privateKey
  ) {
    throw new Error(
      "Missing Firebase secrets. Check FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY.",
    );
  }

  const now = Math.floor(
    Date.now() / 1000,
  );

  const key = await importPKCS8(
    privateKey,
    "RS256",
  );

  const jwt = await new SignJWT({
    scope:
      "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({
      alg: "RS256",
      typ: "JWT",
    })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience(
      "https://oauth2.googleapis.com/token",
    )
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {
        "Content-Type":
          "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type:
          "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    },
  );

  const data = await response.json();

  if (!response.ok) {
    console.error(
      "Google OAuth error:",
      data,
    );

    throw new Error(
      `Failed to get Firebase access token: ${JSON.stringify(
        data,
      )}`,
    );
  }

  return {
    accessToken:
      data.access_token as string,
    projectId,
  };
}

// ============================================================
// SEND FCM NOTIFICATION
// ============================================================

async function sendFcmNotification(
  fcmToken: string,
  accessToken: string,
  projectId: string,
  sosId: string,
  notificationType: string,
  notificationTitle: string,
  notificationBody: string,
  reason?: string,
) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",

      headers: {
        Authorization:
          `Bearer ${accessToken}`,

        "Content-Type":
          "application/json",
      },

      body: JSON.stringify({
        message: {
          token: fcmToken,

          notification: {
            title:
              notificationTitle,
            body:
              notificationBody,
          },

          data: {
            type:
              notificationType,

            sos_id:
              sosId,

            reason:
              reason ?? "",
          },

          android: {
            priority:
              "high",
          },
        },
      }),
    },
  );

  const data =
    await response.json();

  if (!response.ok) {
    console.error(
      "FCM send error:",
      data,
    );

    throw new Error(
      `Failed to send FCM notification: ${JSON.stringify(
        data,
      )}`,
    );
  }

  return data;
}

// ============================================================
// EDGE FUNCTION
// ============================================================

Deno.serve(
  async (req: Request) => {
    try {
      // ========================================================
      // ONLY ALLOW POST
      // ========================================================

      if (req.method !== "POST") {
        return Response.json(
          {
            success: false,
            error:
              "Method not allowed",
          },
          {
            status: 405,
          },
        );
      }

      // ========================================================
      // READ REQUEST
      // ========================================================

      const {
        sos_id,
        type,
        reason,
      } = await req.json();

      if (!sos_id) {
        return Response.json(
          {
            success: false,
            error:
              "sos_id is required",
          },
          {
            status: 400,
          },
        );
      }

      const isCancelled =
        type === "cancelled";

      console.log(
        "================================",
      );

      console.log(
        "PROCESSING SOS NOTIFICATION",
      );

      console.log(
        "SOS ID:",
        sos_id,
      );

      console.log(
        "TYPE:",
        isCancelled
            ? "CANCELLED"
            : "ACTIVE",
      );

      console.log(
        "REASON:",
        reason ?? "N/A",
      );

      console.log(
        "================================",
      );

      // ========================================================
      // GET SOS
      // ========================================================

      const {
        data: sos,
        error: sosError,
      } = await supabase
        .from("sos_alerts")
        .select("*")
        .eq(
          "id",
          sos_id,
        )
        .single();

      if (
        sosError ||
        !sos
      ) {
        console.error(
          "SOS lookup error:",
          sosError,
        );

        return Response.json(
          {
            success: false,
            error:
              "SOS not found",
          },
          {
            status: 404,
          },
        );
      }

      // ========================================================
      // GET SOS USER
      // ========================================================

      const {
        data: sosUser,
        error: sosUserError,
      } = await supabase
        .from("profiles")
        .select("full_name")
        .eq(
          "id",
          sos.user_id,
        )
        .single();

      if (sosUserError) {
        throw new Error(
          `Failed to get SOS user profile: ${sosUserError.message}`,
        );
      }

      const sosUserName =
        sosUser?.full_name ||
        "Your emergency contact";

      console.log(
        "SOS USER:",
        sosUserName,
      );

      // ========================================================
      // GET EMERGENCY CONTACTS
      // ========================================================

      const {
        data: contacts,
        error: contactsError,
      } = await supabase
        .from("emergency_contacts")
        .select(
          "contact_name, contact_phone",
        )
        .eq(
          "user_id",
          sos.user_id,
        );

      if (contactsError) {
        throw new Error(
          `Failed to get emergency contacts: ${contactsError.message}`,
        );
      }

      if (
        !contacts ||
        contacts.length === 0
      ) {
        console.log(
          "NO EMERGENCY CONTACTS FOUND",
        );

        return Response.json({
          success: true,

          message:
            "SOS found, but no emergency contacts exist.",

          notifications_sent:
            0,
        });
      }

      // ========================================================
      // GET CONTACT PHONE NUMBERS
      // ========================================================

      const contactPhones =
        contacts
          .map(
            (contact) =>
              contact.contact_phone,
          )
          .filter(
            (
              phone,
            ): phone is string =>
              typeof phone ===
                "string" &&
              phone.length > 0,
          );

      console.log(
        "CONTACT PHONES:",
        contactPhones,
      );

      // ========================================================
      // FIND APP USERS WITH MATCHING PHONE NUMBERS
      // ========================================================

      const {
        data: profiles,
        error: profilesError,
      } = await supabase
        .from("profiles")
        .select(
          "id, full_name, phone_number, fcm_token",
        )
        .in(
          "phone_number",
          contactPhones,
        );

      if (profilesError) {
        throw new Error(
          `Failed to get recipient profiles: ${profilesError.message}`,
        );
      }

      // ========================================================
      // FILTER USERS WITH FCM TOKENS
      // ========================================================

      const recipients =
        (profiles ?? []).filter(
          (profile) =>
            typeof profile.fcm_token ===
              "string" &&
            profile.fcm_token.length >
              0,
        );

      console.log(
        "RECIPIENTS FOUND:",
        recipients.length,
      );

      if (
        recipients.length === 0
      ) {
        return Response.json({
          success: true,

          message:
            "Emergency contacts found, but none have an FCM token.",

          contacts_found:
            contacts.length,

          notifications_sent:
            0,
        });
      }

      // ========================================================
      // CREATE NOTIFICATION CONTENT
      // ========================================================

    

      const notificationType =
        isCancelled
          ? "sos_cancelled"
          : "sos";

      const notificationTitle =
        isCancelled
          ? "✅ SOS CANCELLED"
          : "🚨 SOS EMERGENCY ALERT";

      const notificationBody =
        isCancelled
          ? `${sosUserName} has cancelled their SOS. Reason: ${
              reason ||
              "Not provided"
            }`
          : `${sosUserName} has pressed Emergency SOS. Contact/help them immediately.`;

      console.log(
        "NOTIFICATION TITLE:",
        notificationTitle,
      );

      console.log(
        "NOTIFICATION BODY:",
        notificationBody,
      );

      // ========================================================
      // GET FIREBASE ACCESS TOKEN
      // ========================================================

      const {
        accessToken,
        projectId,
      } =
        await getFirebaseAccessToken();

      // ========================================================
      // SEND NOTIFICATIONS
      // ========================================================

      const results: Array<{
        user_id: string;
        name: string | null;
        success: boolean;
        result?: unknown;
        error?: string;
      }> = [];

      for (
        const recipient
        of recipients
      ) {
        try {
          console.log(
            `Sending ${notificationType} notification to ${recipient.full_name}`,
          );

          const result =
            await sendFcmNotification(
              recipient.fcm_token,
              accessToken,
              projectId,
              sos_id,
              notificationType,
              notificationTitle,
              notificationBody,
              reason,
            );

          console.log(
            `Notification sent successfully to ${recipient.full_name}`,
          );

          results.push({
            user_id:
              recipient.id,

            name:
              recipient.full_name,

            success:
              true,

            result,
          });
        } catch (error) {
          console.error(
            `Failed to notify ${recipient.full_name}:`,
            error,
          );

          results.push({
            user_id:
              recipient.id,

            name:
              recipient.full_name,

            success:
              false,

            error:
              String(error),
          });
        }
      }

      // ========================================================
      // COUNT SUCCESSFUL NOTIFICATIONS
      // ========================================================

      const successfulNotifications =
        results.filter(
          (result) =>
            result.success,
        ).length;

      console.log(
        "================================",
      );

      console.log(
        "NOTIFICATION PROCESS COMPLETE",
      );

      console.log(
        "SUCCESSFUL:",
        successfulNotifications,
      );

      console.log(
        "TOTAL:",
        recipients.length,
      );

      console.log(
        "================================",
      );

      return Response.json({
        success: true,

        sos_id,

        type:
          notificationType,

        contacts_found:
          contacts.length,

        recipients_found:
          recipients.length,

        notifications_sent:
          successfulNotifications,

        results,
      });
    } catch (error) {
      console.error(
        "FUNCTION ERROR:",
        error,
      );

      return Response.json(
        {
          success: false,

          error:
            String(error),
        },
        {
          status: 500,
        },
      );
    }
  },
);