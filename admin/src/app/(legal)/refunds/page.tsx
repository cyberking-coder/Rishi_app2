import type { Metadata } from "next";
import { legal } from "@/lib/legal";
import { H1, H2, Lead, P } from "../prose";

export const metadata: Metadata = {
  title: "Refund & Cancellation Policy",
};

export default function RefundsPage() {
  return (
    <>
      <H1>Refund &amp; Cancellation Policy</H1>
      <Lead>
        What you can expect if you change your mind, or if something goes
        wrong with a payment.
      </Lead>

      <H2>Live sessions and workshops</H2>
      <P>
        A seat can be cancelled for a full refund up to{" "}
        {legal.sessionRefundHours} hours before the session begins. Write to{" "}
        {legal.email} from the address you registered with, and tell us which
        session.
      </P>
      <P>
        Within {legal.sessionRefundHours} hours of the start, and once a
        session has begun, a seat is non-refundable — the place has been held
        and cannot be resold at that point.
      </P>
      <P>
        If we cancel or reschedule a session, you receive a full refund
        automatically, or a seat at the rescheduled date if you prefer. You do
        not need to ask.
      </P>

      <H2>Courses</H2>
      <P>
        A course can be refunded in full within {legal.courseRefundDays} days
        of purchase, provided no lesson has been opened. Once you have started
        a course the material has been delivered, and it is non-refundable.
      </P>

      <H2>Membership</H2>
      <P>
        Membership is a one-off payment for a fixed period of access. It does
        not renew automatically and there is nothing to cancel — access simply
        ends when the period does.
      </P>
      <P>
        Part-used membership periods are not refundable. If you believe you
        were charged in error, contact us and we will look at it.
      </P>

      <H2>Failed and duplicate payments</H2>
      <P>
        If a payment fails, nothing is charged and nothing is booked. Where an
        amount has left your account on a failed payment, your bank returns it
        automatically, normally within 5–7 working days.
      </P>
      <P>
        If you are charged twice for the same thing, tell us and we will refund
        the duplicate. You do not have to prove it was accidental.
      </P>

      <H2>How refunds are paid</H2>
      <P>
        Approved refunds are returned through Razorpay to the original payment
        method. We start them within 3 working days of approving the request;
        your bank then takes its own time, usually 5–7 working days, and we
        cannot speed that part up.
      </P>

      <H2>Getting in touch</H2>
      <P>
        Email {legal.email} or call {legal.phone}. Please include the payment
        reference from your confirmation message — it is the fastest way for
        us to find the transaction.
      </P>
    </>
  );
}
