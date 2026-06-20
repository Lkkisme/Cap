import { clientEnv } from "./env";

const serverUrl = clientEnv.VITE_SERVER_URL.replace(/\/$/, "");
const downloadUrl = import.meta.env.VITE_DOWNLOAD_URL?.trim().replace(
	/\/$/,
	"",
);
const previousVersionsUrl = import.meta.env.VITE_PREVIOUS_VERSIONS_URL?.trim();

export const CAP_DOWNLOAD_URL = downloadUrl || `${serverUrl}/download`;
export const CAP_PREVIOUS_VERSIONS_URL =
	previousVersionsUrl?.replace(/\/$/, "") || `${serverUrl}/download/versions`;

export const UPDATER_DISABLED = import.meta.env.VITE_DISABLE_UPDATER === "true";
