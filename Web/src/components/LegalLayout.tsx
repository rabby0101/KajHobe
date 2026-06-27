import React from "react";
import Header from "@/components/Header";
import Footer from "@/components/Footer";

interface LegalLayoutProps {
  title: string;
  /** Optional intro shown under the title. */
  intro?: React.ReactNode;
  children: React.ReactNode;
}

/** Shared shell for the static Privacy / Terms / Support pages. */
const LegalLayout: React.FC<LegalLayoutProps> = ({ title, intro, children }) => {
  return (
    <div className="min-h-screen bg-background flex flex-col">
      <Header />
      <main className="flex-1">
        <div className="container mx-auto max-w-3xl px-4 py-12">
          <h1 className="text-3xl md:text-4xl font-bold text-foreground">{title}</h1>
          <p className="mt-2 text-sm text-muted-foreground">Last updated: 2026</p>
          {intro && <div className="mt-4 text-muted-foreground leading-relaxed">{intro}</div>}

          <div className="mt-8 space-y-8 leading-relaxed text-foreground/90">{children}</div>

          <p className="mt-12 rounded-lg border border-dashed border-border bg-muted/30 p-4 text-xs text-muted-foreground">
            This is a starter template provided for convenience and does not
            constitute legal advice. Please have it reviewed and tailored before
            relying on it in production.
          </p>
        </div>
      </main>
      <Footer />
    </div>
  );
};

/** A titled section used within the legal pages. */
export const LegalSection: React.FC<{ heading: string; children: React.ReactNode }> = ({
  heading,
  children,
}) => (
  <section className="space-y-3">
    <h2 className="text-xl font-semibold text-foreground">{heading}</h2>
    <div className="space-y-3 text-muted-foreground">{children}</div>
  </section>
);

export default LegalLayout;
