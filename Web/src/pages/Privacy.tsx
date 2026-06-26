import LegalLayout, { LegalSection } from "@/components/LegalLayout";

const Privacy = () => {
  return (
    <LegalLayout
      title="Privacy Policy"
      intro={
        <p>
          KajHobe ("we", "us") connects people in Khulna, Bangladesh with local
          service providers. This policy explains what information we collect,
          how we use it, and the choices you have.
        </p>
      }
    >
      <LegalSection heading="Information we collect">
        <ul className="list-disc space-y-2 pl-5">
          <li><strong>Account details</strong> — name, email, phone number, and password you provide at sign-up.</li>
          <li><strong>Profile information</strong> — location, bio, profession, hourly/team rates, and avatar.</li>
          <li><strong>Provider verification</strong> — National ID (NID) number and document images, optional certificates, and work-demo links submitted to become a verified provider.</li>
          <li><strong>Activity</strong> — jobs you post, interests, deals, reviews, messages, and notifications generated as you use the service.</li>
          <li><strong>Technical data</strong> — device and usage information needed to operate and secure the app.</li>
        </ul>
      </LegalSection>

      <LegalSection heading="How we use your information">
        <p>
          We use your information to operate the marketplace — matching clients and
          providers, enabling messaging and deals, processing verification, sending
          relevant notifications, preventing abuse, and improving the service.
        </p>
      </LegalSection>

      <LegalSection heading="Provider verification & sensitive data">
        <p>
          NID numbers and verification documents are sensitive. They are stored in
          restricted, non-public storage and are used solely to verify provider
          identity. They are accessible only to authorized reviewers and are not
          shown on public profiles.
        </p>
      </LegalSection>

      <LegalSection heading="Sharing">
        <p>
          We do not sell your personal information. Limited profile details (name,
          rating, location, service categories, and verified status) are visible to
          other users so the marketplace can function. We may share data with service
          providers that help us operate the platform, or when required by law.
        </p>
      </LegalSection>

      <LegalSection heading="Your choices">
        <p>
          You can review and edit your profile at any time, and request deletion of
          your account and associated activity by contacting us. Deleting your account
          removes your jobs, interests, deals, messages, and related records.
        </p>
      </LegalSection>

      <LegalSection heading="Contact">
        <p>
          Questions about privacy? Email{" "}
          <a href="mailto:support@kajhobe.bd" className="text-primary hover:underline">
            support@kajhobe.bd
          </a>.
        </p>
      </LegalSection>
    </LegalLayout>
  );
};

export default Privacy;
