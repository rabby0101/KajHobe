import LegalLayout, { LegalSection } from "@/components/LegalLayout";

const Support = () => {
  return (
    <LegalLayout
      title="Support & Safety"
      intro={
        <p>
          Need help with KajHobe? We're here for you. Reach out and browse the basics
          below.
        </p>
      }
    >
      <LegalSection heading="Contact us">
        <p>
          Email{" "}
          <a href="mailto:support@kajhobe.bd" className="text-primary hover:underline">
            support@kajhobe.bd
          </a>{" "}
          and we'll get back to you. Include your account email and a short description
          (and a screenshot if relevant) so we can help faster.
        </p>
      </LegalSection>

      <LegalSection heading="Safety guidelines">
        <ul className="list-disc space-y-2 pl-5">
          <li>Prefer <strong>verified providers</strong> and check ratings and reviews before agreeing to a deal.</li>
          <li>Agree on scope, price, and timing in writing through in-app messaging before work begins.</li>
          <li>Meet in safe, public places where possible and share details with someone you trust.</li>
          <li>Never share passwords or one-time codes. KajHobe will never ask for your password.</li>
          <li>Report suspicious behavior, off-platform payment requests, or harassment to us right away.</li>
        </ul>
      </LegalSection>

      <LegalSection heading="Common questions">
        <p><strong>How do I become a provider?</strong> Open your Profile and choose "Become a Verified Provider", then submit your NID and (optionally) certificates and work demos for review.</p>
        <p><strong>How do I show interest in a job?</strong> Open a job and tap "Show Interest". If you were declined, you can reapply after a short cooldown, up to the attempt limit.</p>
        <p><strong>How do I delete my account or a job?</strong> You can delete your own job from its detail page. To delete your account and activity, email support.</p>
      </LegalSection>

      <LegalSection heading="Reporting a problem">
        <p>
          Found a bug or a safety concern? Email{" "}
          <a href="mailto:support@kajhobe.bd" className="text-primary hover:underline">
            support@kajhobe.bd
          </a>{" "}
          with the details and we'll investigate.
        </p>
      </LegalSection>
    </LegalLayout>
  );
};

export default Support;
