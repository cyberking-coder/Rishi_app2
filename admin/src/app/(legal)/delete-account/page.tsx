import type { Metadata } from "next";
import { legal } from "@/lib/legal";
import { H1, H2, Lead, P, UL } from "../prose";

export const metadata: Metadata = {
  title: "Delete your account",
};

/**
 * Google Play's User Data policy requires a publicly reachable URL that
 * explains how to delete an account and what happens to the data — and
 * it must be reachable without signing in, which is the same trap that
 * got the privacy policy rejected.
 *
 * The deletion itself happens in the app (Profile → Settings → Delete
 * account), and App Store Guideline 5.1.1(v) requires exactly that. This
 * page documents it and gives anyone who has already uninstalled a way
 * to ask.
 */
export default function DeleteAccountPage() {
  return (
    <>
      <H1>Delete your account</H1>
      <Lead>
        You can delete your {legal.tradingName} account and everything in it
        at any time, from inside the app.
      </Lead>

      <H2>In the app</H2>
      <P>
        Open {legal.tradingName}, go to <strong>Profile</strong> →{" "}
        <strong>Settings</strong> → <strong>Delete account</strong>, and
        confirm. The account is deleted immediately. There is no waiting
        period and nothing to email us about.
      </P>

      <H2>If you have already uninstalled the app</H2>
      <P>
        Write to {legal.email} from the email address the account was
        registered with, and ask us to delete it. We action these within 7
        days. We can only accept the request from the registered address —
        it is the one thing that proves the account is yours.
      </P>

      <H2>What is deleted</H2>
      <P>Deleting the account removes, permanently and without a backup:</P>
      <UL>
        <li>Your login and email address</li>
        <li>Your profile and display name</li>
        <li>Your listening history and lesson progress</li>
        <li>Your conversations with the in-app guide</li>
        <li>The record of which devices you signed in on</li>
        <li>Any certificates issued to you</li>
      </UL>

      <H2>What is kept, and why</H2>
      <P>
        Records of payments are kept, with your identity removed from them.
        Indian tax law requires a seller to retain records of what was sold
        and for how much; it does not require us to keep who bought it, so
        the purchase rows survive with the account reference cleared. They
        can no longer be linked back to you.
      </P>
      <P>
        We also keep a dated note that an account was deleted. It contains no
        name, email or other identifying detail — only the fact and the date,
        so we can answer questions about deletions we have carried out.
      </P>

      <H2>Before you delete</H2>
      <P>
        Deletion cannot be undone, and purchases are not restored by signing
        up again with the same email. If you have bought a course or a seat
        at a live session and only want to stop receiving notifications, turn
        those off in Settings instead — you keep what you paid for.
      </P>

      <H2>Questions</H2>
      <P>
        {legal.email} — or {legal.phone} on a working day.
      </P>
    </>
  );
}
