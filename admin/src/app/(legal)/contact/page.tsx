import type { Metadata } from "next";
import { legal } from "@/lib/legal";
import { H1, H2, Lead, P } from "../prose";

export const metadata: Metadata = { title: "Contact us" };

export default function ContactPage() {
  return (
    <>
      <H1>Contact us</H1>
      <Lead>A real person reads these. We aim to reply within two working days.</Lead>

      <H2>Email</H2>
      <P>
        <a href={`mailto:${legal.email}`} className="underline">
          {legal.email}
        </a>
      </P>

      <H2>Phone</H2>
      <P>
        <a href={`tel:${legal.phone.replace(/\s/g, "")}`} className="underline">
          {legal.phone}
        </a>
      </P>

      <H2>Address</H2>
      <P>
        {legal.businessName}
        <br />
        {legal.address}
      </P>

      <H2>Payment or refund questions</H2>
      <P>
        Include the payment reference from your confirmation message. It is on
        the WhatsApp confirmation we send, and it is the quickest way for us to
        find your transaction.
      </P>

      <H2>Deleting your account</H2>
      <P>
        Write to {legal.email} from the address your account uses and we will
        delete it, along with your listening history and any downloads recorded
        against it. Records of payments are kept where the law requires it.
      </P>
    </>
  );
}
