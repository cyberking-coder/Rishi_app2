import type { Metadata } from "next";
import { legal } from "@/lib/legal";
import { H1, H2, Lead, P, UL } from "../prose";

export const metadata: Metadata = { title: "Privacy Policy" };

export default function PrivacyPage() {
  return (
    <>
      <H1>Privacy Policy</H1>
      <Lead>
        What {legal.tradingName} collects, why, and what we never do with it.
      </Lead>

      <H2>What we collect</H2>
      <UL>
        <li>
          <strong>Account:</strong> your email address, and your name if you
          give one.
        </li>
        <li>
          <strong>Billing:</strong> name, email, phone and state, collected at
          checkout so we can send your confirmation and issue a refund if one
          is due.
        </li>
        <li>
          <strong>Use:</strong> what you have listened to and how far through,
          so the app can carry on where you left off and show your progress.
        </li>
        <li>
          <strong>Device:</strong> a device identifier, to enforce the
          one-account-one-device rule, and a notification token if you allow
          notifications.
        </li>
        <li>
          <strong>Questions to the in-app guide:</strong> stored so the
          conversation is still there when you come back.
        </li>
      </UL>

      <H2>What we never collect</H2>
      <P>
        Card numbers. Payments go directly to Razorpay and card details never
        reach our systems.
      </P>
      <P>
        Recordings. The microphone is used only while you hold the button to
        dictate a question, the speech is converted to text by your own phone,
        and no audio is uploaded or kept.
      </P>

      <H2>Why we use it</H2>
      <UL>
        <li>To give you the content and sessions you have paid for.</li>
        <li>
          To send confirmations, session reminders, and notices that your
          access is ending. These are service messages, not marketing.
        </li>
        <li>To answer your questions in the in-app guide.</li>
        <li>To understand which content is used, in aggregate.</li>
      </UL>

      <H2>Who else sees it</H2>
      <P>
        Only the services that make the app work: Supabase (accounts and
        content), Razorpay (payments), Firebase (notifications), Cloudflare and
        Bunny (audio and video delivery), Anthropic (the in-app guide), and
        Wati (WhatsApp confirmations). Each receives only what its job needs.
      </P>
      <P>
        We do not sell your data, and we do not share it for anyone else&apos;s
        advertising.
      </P>

      <H2>The in-app guide</H2>
      <P>
        Your questions are sent to an AI model to be answered, along with the
        app&apos;s content list and your listening progress so the answers are
        relevant. Your conversation is visible to you alone. Staff cannot read
        it, and clearing it in the app deletes it.
      </P>

      <H2>How long we keep it</H2>
      <P>
        Account and progress data for as long as your account exists. Payment
        records for as long as tax and accounting law requires. Everything else
        goes when you ask us to delete your account.
      </P>

      <H2>Your choices</H2>
      <UL>
        <li>Turn notifications off in your phone&apos;s settings at any time.</li>
        <li>Clear your guide conversation from inside the app.</li>
        <li>
          Ask for a copy of your data, a correction, or deletion of your
          account by writing to {legal.email}.
        </li>
      </UL>

      <H2>Children</H2>
      <P>
        The app is not intended for children under 13, and we do not knowingly
        collect their data. If you believe a child has created an account,
        write to {legal.email} and we will remove it.
      </P>

      <H2>Contact</H2>
      <P>
        {legal.businessName}, {legal.address}. {legal.email} · {legal.phone}.
      </P>
    </>
  );
}
