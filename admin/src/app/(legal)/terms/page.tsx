import type { Metadata } from "next";
import Link from "next/link";
import { legal } from "@/lib/legal";
import { H1, H2, Lead, P, UL } from "../prose";

export const metadata: Metadata = { title: "Terms & Conditions" };

export default function TermsPage() {
  return (
    <>
      <H1>Terms &amp; Conditions</H1>
      <Lead>
        The agreement between you and {legal.businessName} when you use{" "}
        {legal.tradingName}.
      </Lead>

      <H2>Who we are</H2>
      <P>
        {legal.tradingName} is operated by {legal.businessName},{" "}
        {legal.address}. You can reach us at {legal.email} or {legal.phone}.
      </P>

      <H2>What we provide</H2>
      <P>
        A mobile application offering guided meditation audio, video courses,
        and seats at live online sessions. Some content is free; some requires
        a membership or a one-off purchase.
      </P>

      <H2>Your account</H2>
      <UL>
        <li>
          You need an account to use the app, and you are responsible for
          keeping your login details to yourself.
        </li>
        <li>
          <strong>One account, one device.</strong> An account can be signed in
          on a single device at a time. Signing in elsewhere will not work
          until the first device is released — contact us if you have changed
          phones.
        </li>
        <li>
          Content is licensed to you personally. Recording, downloading outside
          the app, re-sharing or reselling it is not permitted.
        </li>
      </UL>

      <H2>Payments</H2>
      <UL>
        <li>
          All prices are in Indian Rupees and include applicable taxes unless
          stated otherwise.
        </li>
        <li>
          Payments are processed by Razorpay. We never see or store your card
          details.
        </li>
        <li>
          Access is granted only once the payment is confirmed by the gateway.
          If confirmation is delayed, access follows shortly after — it is not
          lost.
        </li>
        <li>
          Prices can change. A change never affects something you have already
          paid for.
        </li>
      </UL>

      <H2>Delivery</H2>
      <P>
        Everything sold here is digital and delivered inside the app. There is
        nothing to ship. A purchase unlocks immediately on confirmation; a
        session seat gives you a join link on the session card at the
        scheduled time.
      </P>

      <H2>Live sessions</H2>
      <P>
        Sessions run at the advertised time on a third-party meeting platform.
        You need a working internet connection and, on some platforms, that
        platform&apos;s own app. We may reschedule a session; if we do, your
        seat carries over or is refunded — see the{" "}
        <Link href="/refunds" className="underline">
          Refund Policy
        </Link>
        .
      </P>

      <H2>What this is not</H2>
      <P>
        Meditation and the guidance in this app support wellbeing. They are not
        medical treatment, psychiatric care, or a substitute for either.
        Nothing here diagnoses a condition or replaces advice from a qualified
        professional. If you are unwell, in crisis, or unsure whether a
        practice is right for you, speak to a doctor or a mental-health
        professional.
      </P>
      <P>
        If you are in distress, help is free and available: Tele-MANAS 14416,
        AASRA 9820466726, Vandrevala Foundation 9999 666 555, iCall 9152987821.
        In an emergency call 112.
      </P>

      <H2>Ending access</H2>
      <P>
        We may suspend an account that shares logins, redistributes content, or
        abuses other members or staff. Where we do that without cause, we
        refund the unused portion of anything you have paid for.
      </P>

      <H2>Changes and disputes</H2>
      <P>
        These terms may change; the current version is always the one on this
        page, dated below. Continuing to use the app after a change means you
        accept it. These terms are governed by the laws of India, and the
        courts of {legal.jurisdiction} have jurisdiction.
      </P>
    </>
  );
}
