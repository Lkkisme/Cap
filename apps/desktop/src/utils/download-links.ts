import { clientEnv } from "./env";

const serverUrl = clientEnv.VITE_SERVER_URL.replace(/\/$/, "");

export const CAP_DOWNLOAD_URL = `${serverUrl}/download`;
export const CAP_PREVIOUS_VERSIONS_URL = `${serverUrl}/download/versions`;

export const UPDATER_DISABLED = import.meta.env.VITE_DISABLE_UPDATER === "true";
