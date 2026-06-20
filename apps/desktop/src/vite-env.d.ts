/// <reference types="vinxi/types/client" />

interface ImportMetaEnv {
	readonly VITE_SERVER_URL: string;
	readonly VITE_DISABLE_UPDATER?: string;
	readonly VITE_DOWNLOAD_URL?: string;
	readonly VITE_PREVIOUS_VERSIONS_URL?: string;
}

interface ImportMeta {
	readonly env: ImportMetaEnv;
}
