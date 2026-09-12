import { useTranslation } from "react-i18next";
import { Link } from "../../router";
import { DOC_PAGE_IDS } from "./pages";

type TextSection = {
  title: string;
  body: string[];
};

type TeamMember = {
  name: string;
  role: string;
  institution: string;
  email: string;
  photo: string;
  github?: string;
  linkedin?: string;
};

export function DocsIndex() {
  const { t } = useTranslation("docs");
  const overviewSections = t("overview.sections", { returnObjects: true }) as TextSection[];
  const productSections = t("overview.product_sections", { returnObjects: true }) as TextSection[];
  const team = t("overview.team.members", { returnObjects: true }) as TeamMember[];

  return (
    <div className="page docs-page">
      <div className="docs-hero">
        <div className="eyebrow">{t("overview.eyebrow")}</div>
        <h2>{t("overview.title")}</h2>
        <p>{t("overview.lede")}</p>
      </div>

      <section className="docs-section">
        <h3>{t("overview.institution_title")}</h3>
        <p>{t("overview.institution_body")}</p>
      </section>

      <div className="docs-section-grid">
        {overviewSections.map((section) => (
          <section key={section.title} className="docs-section">
            <h3>{section.title}</h3>
            {section.body.map((paragraph) => (
              <p key={paragraph}>{paragraph}</p>
            ))}
          </section>
        ))}
      </div>

      <section className="docs-section">
        <h3>{t("overview.product_title")}</h3>
        <div className="docs-feature-list">
          {productSections.map((section) => (
            <div key={section.title} className="docs-feature">
              <h4>{section.title}</h4>
              {section.body.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
            </div>
          ))}
        </div>
      </section>

      <section className="docs-section">
        <h3>{t("overview.team.title")}</h3>
        <p>{t("overview.team.body")}</p>
        <div className="docs-team-list">
          {team.map((member) => (
            <article key={member.name} className="docs-team-profile">
              <img className="docs-team-photo" src={member.photo} alt={member.name} loading="lazy" />
              <div>
                <h4>{member.name}</h4>
                <p className="docs-team-role">{member.role}</p>
                <p className="docs-team-institution">{member.institution}</p>
                <div className="docs-team-links">
                  <a href={`mailto:${member.email}`}>{member.email}</a>
                  {member.github && (
                    <a href={member.github} target="_blank" rel="noreferrer">
                      GitHub
                    </a>
                  )}
                  {member.linkedin && (
                    <a href={member.linkedin} target="_blank" rel="noreferrer">
                      LinkedIn
                    </a>
                  )}
                </div>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="docs-section">
        <h3>{t("overview.technical_title")}</h3>
        <p>
          {t("pipeline_link_intro")}{" "}
          <a href="https://bymaxanjos.github.io/climasus4r/" target="_blank" rel="noreferrer">
            {t("pipeline_link_label")}
          </a>
        </p>
        <nav className="docs-link-list" aria-label={t("overview.technical_title")}>
          {DOC_PAGE_IDS.map((id) => (
            <Link key={id} to={`/docs/${id}`}>
              {t(`page.${id}.title`)}
            </Link>
          ))}
        </nav>
      </section>
    </div>
  );
}
