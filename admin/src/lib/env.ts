// Centralized env access with clear errors when something is missing.

function required(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const env = {
  supabaseUrl: () =>
    required("NEXT_PUBLIC_SUPABASE_URL", process.env.NEXT_PUBLIC_SUPABASE_URL),
  supabaseAnonKey: () =>
    required(
      "NEXT_PUBLIC_SUPABASE_ANON_KEY",
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    ),
  supabaseServiceRoleKey: () =>
    required(
      "SUPABASE_SERVICE_ROLE_KEY",
      process.env.SUPABASE_SERVICE_ROLE_KEY,
    ),
  r2: () => ({
    accountId: required("R2_ACCOUNT_ID", process.env.R2_ACCOUNT_ID),
    accessKeyId: required("R2_ACCESS_KEY_ID", process.env.R2_ACCESS_KEY_ID),
    secretAccessKey: required(
      "R2_SECRET_ACCESS_KEY",
      process.env.R2_SECRET_ACCESS_KEY,
    ),
    bucket: required("R2_BUCKET", process.env.R2_BUCKET),
    publicBaseUrl: process.env.R2_PUBLIC_BASE_URL ?? "",
  }),
  bunny: () => ({
    apiKey: required("BUNNY_STREAM_API_KEY", process.env.BUNNY_STREAM_API_KEY),
    libraryId: required("BUNNY_STREAM_LIBRARY_ID", process.env.BUNNY_STREAM_LIBRARY_ID),
  }),
  checkoutTokenSecret: () =>
    required("CHECKOUT_TOKEN_SECRET", process.env.CHECKOUT_TOKEN_SECRET),
  razorpay: () => ({
    keyId: required("RAZORPAY_KEY_ID", process.env.RAZORPAY_KEY_ID),
    keySecret: required(
      "RAZORPAY_KEY_SECRET",
      process.env.RAZORPAY_KEY_SECRET,
    ),
  }),
};
