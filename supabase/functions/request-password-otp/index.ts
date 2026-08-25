import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get(
  "SUPABASE_SERVICE_ROLE_KEY",
);
const resendApiKey = Deno.env.get("RESEND_API_KEY");

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Missing Supabase environment variables");
}

if (!resendApiKey) {
  throw new Error("Missing RESEND_API_KEY secret");
}

const supabase = createClient(
  supabaseUrl,
  supabaseServiceRoleKey,
);

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return Response.json(
        {
          success: false,
          error: "Method not allowed",
        },
        {
          status: 405,
        },
      );
    }

    const { email } = await req.json();

    if (!email || typeof email !== "string") {
      return Response.json(
        {
          success: false,
          error: "Email is required",
        },
        {
          status: 400,
        },
      );
    }

    const normalizedEmail = email.trim().toLowerCase();

    console.log(
      "Password OTP requested for:",
      normalizedEmail,
    );

    // ============================================================
    // FIND USER
    // ============================================================

    const {
      data: usersData,
      error: usersError,
    } = await supabase.auth.admin.listUsers();

    if (usersError) {
      console.error(
        "User lookup error:",
        usersError,
      );

      throw new Error(
        `Failed to look up user: ${usersError.message}`,
      );
    }

    const user = usersData.users.find(
      (item) =>
        item.email?.toLowerCase() === normalizedEmail,
    );

    if (!user) {
      return Response.json(
        {
          success: false,
          error: "No account found with this email address.",
        },
        {
          status: 404,
        },
      );
    }

    // ============================================================
    // GENERATE 6-DIGIT OTP
    // ============================================================

    const otp = Math.floor(
      100000 + Math.random() * 900000,
    ).toString();

    const expiresAt = new Date(
      Date.now() + 10 * 60 * 1000,
    ).toISOString();

    console.log(
      `Generated OTP for ${normalizedEmail}`,
    );

    // ============================================================
    // REMOVE PREVIOUS UNUSED OTPs FOR THIS EMAIL
    // ============================================================

    const { error: deleteError } = await supabase
      .from("password_resets")
      .delete()
      .eq("email", normalizedEmail);

    if (deleteError) {
      console.error(
        "Failed to remove previous OTPs:",
        deleteError,
      );

      throw new Error(
        `Failed to prepare password reset: ${deleteError.message}`,
      );
    }

    // ============================================================
    // STORE OTP
    // ============================================================

    const {
      error: insertError,
    } = await supabase
      .from("password_resets")
      .insert({
        user_id: user.id,
        email: normalizedEmail,
        otp_code: otp,
        expires_at: expiresAt,
      });

    if (insertError) {
      console.error(
        "OTP database insert error:",
        insertError,
      );

      throw new Error(
        `Failed to create password reset OTP: ${insertError.message}`,
      );
    }

    // ============================================================
    // SEND OTP EMAIL USING RESEND
    // ============================================================

    const emailResponse = await fetch(
      "https://api.resend.com/emails",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "TrekCure <onboarding@resend.dev>",
          to: [normalizedEmail],
          subject: "Your TrekCure Password Reset OTP",
          html: `
            <div style="
              font-family: Arial, sans-serif;
              max-width: 600px;
              margin: auto;
              padding: 24px;
            ">
              <h2>TrekCure Password Reset</h2>

              <p>
                Use the following OTP to reset your password:
              </p>

              <div style="
                font-size: 32px;
                font-weight: bold;
                letter-spacing: 8px;
                padding: 20px;
                background: #f2f2f2;
                text-align: center;
                border-radius: 8px;
                margin: 24px 0;
              ">
                ${otp}
              </div>

              <p>
                This OTP will expire in <strong>10 minutes</strong>.
              </p>

              <p>
                If you did not request a password reset,
                you can safely ignore this email.
              </p>

              <br>

              <p>
                — TrekCure
              </p>
            </div>
          `,
        }),
      },
    );

    const emailData = await emailResponse.json();

    if (!emailResponse.ok) {
      console.error(
        "Resend email error:",
        emailData,
      );

      throw new Error(
        `Failed to send OTP email: ${JSON.stringify(emailData)}`,
      );
    }

    console.log(
      "OTP email sent successfully:",
      emailData,
    );

    return Response.json(
      {
        success: true,
        message:
          "Password reset OTP sent to your email address.",
      },
      {
        status: 200,
      },
    );
  } catch (error) {
    console.error(
      "REQUEST PASSWORD OTP ERROR:",
      error,
    );

    return Response.json(
      {
        success: false,
        error: String(error),
      },
      {
        status: 500,
      },
    );
  }
});