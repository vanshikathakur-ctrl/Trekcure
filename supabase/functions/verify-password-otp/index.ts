import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");

const supabaseServiceRoleKey = Deno.env.get(
  "SUPABASE_SERVICE_ROLE_KEY",
);

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Missing Supabase environment variables");
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

    const {
      email,
      otp,
      newPassword,
    } = await req.json();

    // ============================================================
    // VALIDATION
    // ============================================================

    if (!email || typeof email !== "string") {
      return Response.json(
        {
          success: false,
          error: "Email is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (!otp || typeof otp !== "string") {
      return Response.json(
        {
          success: false,
          error: "OTP is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (!newPassword || typeof newPassword !== "string") {
      return Response.json(
        {
          success: false,
          error: "New password is required.",
        },
        {
          status: 400,
        },
      );
    }

    if (otp.length != 6) {
      return Response.json(
        {
          success: false,
          error: "Invalid OTP.",
        },
        {
          status: 400,
        },
      );
    }

    if (newPassword.length < 6) {
      return Response.json(
        {
          success: false,
          error: "Password must be at least 6 characters.",
        },
        {
          status: 400,
        },
      );
    }

    const normalizedEmail =
        email.trim().toLowerCase();

    console.log(
      "Verifying password reset OTP for:",
      normalizedEmail,
    );

    // ============================================================
    // FIND OTP
    // ============================================================

    const {
      data: resetRequest,
      error: resetError,
    } = await supabase
      .from("password_resets")
      .select("*")
      .eq("email", normalizedEmail)
      .eq("otp_code", otp.trim())
      .order("created_at", {
        ascending: false,
      })
      .limit(1)
      .maybeSingle();

    if (resetError) {
      console.error(
        "OTP lookup error:",
        resetError,
      );

      throw new Error(
        `Failed to verify OTP: ${resetError.message}`,
      );
    }

    if (!resetRequest) {
      return Response.json(
        {
          success: false,
          error: "Invalid OTP code.",
        },
        {
          status: 400,
        },
      );
    }

    // ============================================================
    // CHECK EXPIRY
    // ============================================================

    const expiresAt =
        new Date(resetRequest.expires_at);

    if (expiresAt.getTime() < Date.now()) {
      return Response.json(
        {
          success: false,
          error:
              "This OTP has expired. Please request a new one.",
        },
        {
          status: 400,
        },
      );
    }

    // ============================================================
    // UPDATE PASSWORD
    // ============================================================

    const {
      error: updateError,
    } = await supabase.auth.admin.updateUserById(
      resetRequest.user_id,
      {
        password: newPassword,
      },
    );

    if (updateError) {
      console.error(
        "Password update error:",
        updateError,
      );

      throw new Error(
        `Failed to update password: ${updateError.message}`,
      );
    }

    // ============================================================
    // DELETE USED OTP
    // ============================================================

    const {
      error: deleteError,
    } = await supabase
      .from("password_resets")
      .delete()
      .eq("id", resetRequest.id);

    if (deleteError) {
      console.error(
        "Could not delete used OTP:",
        deleteError,
      );
    }

    console.log(
      "Password successfully updated for:",
      normalizedEmail,
    );

    return Response.json(
      {
        success: true,
        message:
            "Password updated successfully.",
      },
      {
        status: 200,
      },
    );
  } catch (error) {
    console.error(
      "VERIFY PASSWORD OTP ERROR:",
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