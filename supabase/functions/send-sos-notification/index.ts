import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({
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
      senderName,
    } = await req.json();

    if (!sosId) {
      return new Response(
        JSON.stringify({
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

    if (
      type !== "sos" &&
      type !== "cancelled"
    ) {
      return new Response(
        JSON.stringify({
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
        Deno.env.get(
          "GOOGLE_SERVICE_ACCOUNT",
        );

    if (!serviceAccountJson) {
      throw new Error(
        "GOOGLE_SERVICE_ACCOUNT secret is missing.",
      );
    }

    const serviceAccount =
        JSON.parse(
          serviceAccountJson,
        );

    const supabaseUrl =
        Deno.env.get("SUPABASE_URL")!;

    const serviceRoleKey =
        Deno.env.get(
          "SUPABASE_SERVICE_ROLE_KEY",
        )!;

    const supabase =
        createClient(
          supabaseUrl,
          serviceRoleKey,
        );

    const {
      data: profiles,
      error: profilesError,
    } = await supabase
        .from("profiles")
        .select("id, fcm_token")
        .not(
          "fcm_token",
          "is",
          null,
        );

    if (profilesError) {
      throw profilesError;
    }

    if (
      profiles == null ||
      profiles.length == 0
    ) {
      return new Response(
        JSON.stringify({
          success: true,
          message:
              "No FCM tokens found.",
        }),
        {
          headers: {
            "Content-Type":
                "application/json",
          },
        },
      );
    }

    const jwtClient =
        new JWT({
          email:
              serviceAccount.client_email,
          key:
              serviceAccount.private_key,
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

    const isCancelled =
        type == "cancelled";

    const title =
        isCancelled
            ? "SOS CANCELLED"
            : "SOS EMERGENCY ALERT";

    const notificationBody =
    isCancelled
        ? `${senderName ?? "A tourist"} has cancelled the emergency SOS.`
        : `${senderName ?? "A tourist"} needs emergency assistance.`;

    const projectId =
        serviceAccount.project_id;

    let successCount = 0;

    for (
      const profile
          of profiles
    ) {
      const fcmToken =
          profile["fcm_token"];

      if (
        !fcmToken ||
        typeof fcmToken !==
            "string"
      ) {
        continue;
      }

      try {
        const response =
            await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type":
                  "application/json",
              Authorization:
                  `Bearer ${accessToken}`,
            },
            body:
                JSON.stringify({
              message: {
                token: fcmToken,

                notification: {
                  title: title,
                  body:
                      notificationBody,
                },

                data: {
                  type:
                      isCancelled
                          ? "sos_cancelled"
                          : "sos",
                  sos_id:
                      sosId.toString(),
                },

                android: {
                  priority:
                      "high",
                  notification: {
                    channel_id:
                        "sos_alerts",
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

          console.log(
            "FCM notification sent:",
            responseText,
          );
        } else {
          console.error(
            "FCM ERROR:",
            response.status,
            responseText,
          );
        }
      } catch (e) {
        console.error(
          "Failed to send FCM notification:",
          e,
        );
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sentTo:
            successCount,
      }),
      {
        headers: {
          "Content-Type":
              "application/json",
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
          "Content-Type":
              "application/json",
        },
      },
    );
  }
});