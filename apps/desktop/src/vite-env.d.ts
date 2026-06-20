/// <reference types="vinxi/types/client" />

interface ImportMetaEnv {
	readonly VITE_SERVER_URL: string;
	readonly VITE_DISABLE_UPDATER?: string;
}

interface ImportMeta {
	readonly env: ImportMetaEnv;
}
