import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { SignJWT, importPKCS8 } from "npm:jose@5";

// ----------------------------------------------------
// Get a Google OAuth access token using Firebase
// service account credentials
// ----------------------------------------------------
async function getFirebaseAccessToken() {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");

  // Convert \n stored in Supabase secret into real line breaks
  const privateKey = Deno.env
    .get("FIREBASE_PRIVATE_KEY")
    ?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      "Missing Firebase secrets. Check FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY."
    );
  }

  const now = Math.floor(Date.now() / 1000);

  const key = await importPKCS8(privateKey, "RS256");

  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({
      alg: "RS256",
      typ: "JWT",
    })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
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
    console.error("Google OAuth error:", data);
    throw new Error("Failed to get Firebase access token");
  }

  return {
    accessToken: data.access_token,
    projectId,
  };
}

// ----------------------------------------------------
// Send notification to one FCM device token
// ----------------------------------------------------
async function sendFcmNotification(
  fcmToken: string,
  accessToken: string,
  projectId: string,
  sosId: string,
) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,

          notification: {
            title: "🚨 SOS EMERGENCY ALERT",
            body: "Your emergency contact has activated an SOS!",
          },

          data: {
            type: "sos",
            sos_id: sosId,
          },

          android: {
            priority: "high",
          },
        },
      }),
    },
  );

  const data = await response.json();

  if (!response.ok) {
    console.error("FCM send error:", data);
    throw new Error(
      `Failed to send FCM notification: ${JSON.stringify(data)}`,
    );
  }

  return data;
}

// ----------------------------------------------------
// Main Edge Function
// ----------------------------------------------------
export default {
  fetch: withSupabase(
    { auth: ["publishable", "secret"] },
    async (req, ctx) => {
      try {
        const { sos_id } = await req.json();

        if (!sos_id) {
          return Response.json(
            {
              success: false,
              error: "sos_id is required",
            },
            { status: 400 },
          );
        }

        console.log("Processing SOS:", sos_id);

        // --------------------------------------------
        // 1. Get SOS alert
        // --------------------------------------------
        const { data: sos, error: sosError } =
          await ctx.supabaseAdmin
            .from("sos_alerts")
            .select("*")
            .eq("id", sos_id)
            .single();

        if (sosError || !sos) {
          console.error("SOS lookup error:", sosError);

          return Response.json(
            {
              success: false,
              error: "SOS not found",
            },
            { status: 404 },
          );
        }

        console.log("SOS belongs to user:", sos.user_id);

        // --------------------------------------------
        // 2. Find emergency contacts of SOS user
        // --------------------------------------------
        const { data: contacts, error: contactsError } =
          await ctx.supabaseAdmin
            .from("emergency_contacts")
            .select("contact_name, contact_phone")
            .eq("user_id", sos.user_id);

        if (contactsError) {
          throw new Error(
            `Failed to get emergency contacts: ${contactsError.message}`,
          );
        }

        if (!contacts || contacts.length === 0) {
          return Response.json({
            success: true,
            message: "SOS found, but no emergency contacts exist.",
            notifications_sent: 0,
          });
        }

        console.log("Emergency contacts found:", contacts.length);

        // Get all contact phone numbers
        const contactPhones = contacts
          .map((contact) => contact.contact_phone)
          .filter(Boolean);

        // --------------------------------------------
        // 3. Find matching profiles and FCM tokens
        // --------------------------------------------
        const { data: profiles, error: profilesError } =
          await ctx.supabaseAdmin
            .from("profiles")
            .select("id, full_name, phone_number, fcm_token")
            .in("phone_number", contactPhones);

        if (profilesError) {
          throw new Error(
            `Failed to get recipient profiles: ${profilesError.message}`,
          );
        }

        const recipients = (profiles ?? []).filter(
          (profile) => profile.fcm_token,
        );

        if (recipients.length === 0) {
          return Response.json({
            success: true,
            message:
              "Emergency contacts found, but none have an FCM token.",
            contacts_found: contacts.length,
            notifications_sent: 0,
          });
        }

        console.log(
          "Recipients with FCM tokens:",
          recipients.length,
        );

        // --------------------------------------------
        // 4. Get Firebase access token
        // --------------------------------------------
        const { accessToken, projectId } =
          await getFirebaseAccessToken();

        // --------------------------------------------
        // 5. Send notification to every recipient
        // --------------------------------------------
        const results = [];

        for (const recipient of recipients) {
          try {
            const result = await sendFcmNotification(
              recipient.fcm_token,
              accessToken,
              projectId,
              sos_id,
            );

            console.log(
              `Notification sent to ${recipient.full_name}`,
            );

            results.push({
              user_id: recipient.id,
              name: recipient.full_name,
              success: true,
              result,
            });
          } catch (error) {
            console.error(
              `Failed to notify ${recipient.full_name}:`,
              error,
            );

            results.push({
              user_id: recipient.id,
              name: recipient.full_name,
              success: false,
              error: String(error),
            });
          }
        }

        const successfulNotifications = results.filter(
          (result) => result.success,
        ).length;

        return Response.json({
          success: true,
          sos_id,
          contacts_found: contacts.length,
          recipients_found: recipients.length,
          notifications_sent: successfulNotifications,
          results,
        });
      } catch (error) {
        console.error("FUNCTION ERROR:", error);

        return Response.json(
          {
            success: false,
            error: String(error),
          },
          { status: 500 },
        );
      }
    },
  ),
};