// The domain lives in the BINDING here, not in the call — the shape a React
// codebase falls into once a subtree has its own domain.
import { useT } from "@/lib/i18n/react";

export function Panel() {
  const t = useT("notifications");
  const tp = useT("notifications");
  const publik = useT();

  return [t("Case closed"), tp("Case reopened"), publik("Book now")];
}
