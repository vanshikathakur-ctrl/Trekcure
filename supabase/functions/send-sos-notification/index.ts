import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Method not allowed",
        }),
        {
          status: 405,
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    const {
      sosId,
      type,
      reason,
    } = await req.json();

    if (!sosId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing SOS ID",
        }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    if (type !== "sos" && type !== "cancelled") {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Invalid notification type",
        }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    const serviceAccountJson =
      Deno.env.get("GOOGLE_SERVICE_ACCOUNT");

    if (!serviceAccountJson) {
      throw new Error(
        "GOOGLE_SERVICE_ACCOUNT secret is missing.",
      );
    }

    const serviceAccount =
      JSON.parse(serviceAccountJson);

    const supabaseUrl =
      Deno.env.get("SUPABASE_URL");

    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error(
        "Supabase environment variables are missing.",
      );
    }

    const supabase = createClient(
      supabaseUrl,
      serviceRoleKey,
    );

    // ------------------------------------------------------------
    // GET THE SOS
    // ------------------------------------------------------------

    const {
      data: sos,
      error: sosError,
    } = await supabase
      .from("sos_alerts")
      .select(
        "id, user_id, status, cancellation_reason",
      )
      .eq("id", sosId)
      .single();

    if (sosError || !sos) {
      throw new Error(
        `SOS not found: ${
          sosError?.message ?? "unknown error"
        }`,
      );
    }

    // ------------------------------------------------------------
    // GET SOS OWNER
    // ------------------------------------------------------------

    const {
      data: sosUser,
      error: sosUserError,
    } = await supabase
      .from("profiles")
      .select("id, full_name, phone_number")
      .eq("id", sos.user_id)
      .single();

    if (sosUserError || !sosUser) {
      throw new Error(
        `Failed to get SOS user: ${
          sosUserError?.message ?? "unknown error"
        }`,
      );
    }

    const senderName =
      sosUser.full_name?.trim() ||
      "A TrekCure user";

    // ------------------------------------------------------------
    // GET EMERGENCY CONTACTS
    // ------------------------------------------------------------

    const {
      data: contacts,
      error: contactsError,
    } = await supabase
      .from("emergency_contacts")
      .select("contact_name, contact_phone")
      .eq("user_id", sos.user_id);

    if (contactsError) {
      throw new Error(
        `Failed to get emergency contacts: ${
          contactsError.message
        }`,
      );
    }

    if (!contacts || contacts.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message:
            "No emergency contacts configured.",
          notifications_sent: 0,
        }),
        {
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ------------------------------------------------------------
    // MATCH EMERGENCY CONTACT PHONE NUMBERS
    // TO TREKCURE PROFILES
    // ------------------------------------------------------------

    const contactPhones = contacts
      .map((contact) =>
        typeof contact.contact_phone === "string"
          ? contact.contact_phone.trim()
          : "",
      )
      .filter((phone) => phone.length > 0);

    if (contactPhones.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message:
            "Emergency contacts have no valid phone numbers.",
          notifications_sent: 0,
        }),
        {
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    const {
      data: profiles,
      error: profilesError,
    } = await supabase
      .from("profiles")
      .select("id, full_name, phone_number, fcm_token")
      .in("phone_number", contactPhones);

    if (profilesError) {
      throw new Error(
        `Failed to find contact profiles: ${
          profilesError.message
        }`,
      );
    }

    // Never notify the SOS owner themselves.
    const recipients = (profiles ?? []).filter(
      (profile) =>
        profile.id !== sos.user_id &&
        typeof profile.fcm_token === "string" &&
        profile.fcm_token.trim().length > 0,
    );

    if (recipients.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message:
            "Emergency contacts found, but no matching TrekCure profiles have FCM tokens.",
          contacts_found: contacts.length,
          notifications_sent: 0,
        }),
        {
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ------------------------------------------------------------
    // GOOGLE FCM AUTHENTICATION
    // ------------------------------------------------------------

    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: [
        "https://www.googleapis.com/auth/firebase.messaging",
      ],
    });

    const tokenResponse =
      await jwtClient.authorize();

    const accessToken =
      tokenResponse.access_token;

    if (!accessToken) {
      throw new Error(
        "Failed to generate Google access token.",
      );
    }

    const projectId =
      serviceAccount.project_id;

    const isCancelled =
      type === "cancelled";

    const cancellationReason =
      (
        reason ??
        sos.cancellation_reason ??
        "Not specified"
      ).toString().trim() || "Not specified";

    const title = isCancelled
      ? "✅ SOS CANCELLED"
      : "🚨 SOS EMERGENCY ALERT";

    const notificationBody = isCancelled
      ? `${senderName} has cancelled the emergency SOS. Reason: ${cancellationReason}.`
      : `${senderName} needs emergency assistance.`;

    // ------------------------------------------------------------
    // SEND FCM TO EMERGENCY CONTACTS ONLY
    // ------------------------------------------------------------

    let successCount = 0;

    const results: Array<{
      user_id: string;
      name: string | null;
      success: boolean;
      error?: string;
    }> = [];

    for (const profile of recipients) {
      const fcmToken =
        profile.fcm_token?.toString().trim();

      if (!fcmToken) {
        continue;
      }

      try {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization:
                `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: fcmToken,

                notification: {
                  title,
                  body: notificationBody,
                },

                data: {
                  type: isCancelled
                    ? "sos_cancelled"
                    : "sos",
                  sos_id: sosId.toString(),
                  cancellation_reason:
                    isCancelled
                      ? cancellationReason
                      : "",
                },

                android: {
                  priority: "high",
                  notification: {
                    channel_id: "sos_alerts",
                  },
                },
              },
            }),
          },
        );

        const responseText =
          await response.text();

        if (response.ok) {
          successCount++;

          results.push({
            user_id: profile.id,
            name: profile.full_name,
            success: true,
          });

          console.log(
            "FCM notification sent:",
            profile.id,
          );
        } else {
          results.push({
            user_id: profile.id,
            name: profile.full_name,
            success: false,
            error: responseText,
          });

          console.error(
            "FCM ERROR:",
            response.status,
            responseText,
          );
        }
      } catch (error) {
        results.push({
          user_id: profile.id,
          name: profile.full_name,
          success: false,
          error: String(error),
        });

        console.error(
          "Failed to send FCM notification:",
          error,
        );
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sos_id: sosId,
        type,
        contacts_found: contacts.length,
        matching_profiles: recipients.length,
        notifications_sent: successCount,
        results,
      }),
      {
        headers: {
          "Content-Type": "application/json",
        },
      },
    );
  } catch (error) {
    console.error(
      "EDGE FUNCTION ERROR:",
      error,
    );

    return new Response(
      JSON.stringify({
        success: false,
        error:
          error instanceof Error
            ? error.message
            : "Unknown error",
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
        },
      },
    );
  }
});