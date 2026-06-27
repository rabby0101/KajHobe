import LegalLayout, { LegalSection } from "@/components/LegalLayout";

const Terms = () => {
  return (
    <LegalLayout
      title="Terms & Conditions"
      intro={
        <p>
          These terms govern your use of KajHobe. By creating an account or using
          the service, you agree to them.
        </p>
      }
    >
      <LegalSection heading="Accounts">
        <p>
          You must provide accurate information and keep your credentials secure.
          You are responsible for activity on your account. You must be legally able
          to enter into contracts to use KajHobe.
        </p>
      </LegalSection>

      <LegalSection heading="Provider verification">
        <p>
          Becoming a verified provider requires submitting identity documents (NID)
          and, optionally, certificates and work demos. Verification is reviewed
          manually and may be approved or rejected at our discretion. Misrepresenting
          your identity or qualifications may result in removal.
        </p>
      </LegalSection>

      <LegalSection heading="Jobs, interests & deals">
        <p>
          Clients post jobs; providers express interest and negotiate. Agreements
          ("deals") are made directly between the client and provider. KajHobe
          provides the platform but is not a party to those agreements and does not
          guarantee the quality, safety, or legality of any service.
        </p>
      </LegalSection>

      <LegalSection heading="Payments & escrow">
        <p>
          Where escrow or payout features are used, funds are handled according to the
          flow shown in the app. You agree to complete payments and payouts honestly
          and to resolve disputes in good faith. Fees, if any, will be disclosed before
          they apply.
        </p>
      </LegalSection>

      <LegalSection heading="Acceptable use">
        <p>
          Do not use KajHobe for unlawful, fraudulent, abusive, or harassing activity,
          and do not attempt to disrupt or misuse the platform. We may suspend or remove
          accounts that violate these terms.
        </p>
      </LegalSection>

      <LegalSection heading="Disclaimer & liability">
        <p>
          The service is provided "as is" without warranties. To the extent permitted
          by law, KajHobe is not liable for damages arising from interactions between
          users or from use of the platform.
        </p>
      </LegalSection>

      <LegalSection heading="Changes & contact">
        <p>
          We may update these terms; continued use means you accept the changes.
          Questions? Email{" "}
          <a href="mailto:support@kajhobe.bd" className="text-primary hover:underline">
            support@kajhobe.bd
          </a>.
        </p>
      </LegalSection>
    </LegalLayout>
  );
};

export default Terms;
