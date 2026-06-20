import { A, type RouteSectionProps } from "@solidjs/router";
import { getVersion } from "@tauri-apps/api/app";
import { getCurrentWindow, LogicalSize } from "@tauri-apps/api/window";
import * as shell from "@tauri-apps/plugin-shell";
import "@total-typescript/ts-reset/filter-boolean";
import { createResource, For, onMount, Show, Suspense } from "solid-js";
import { CapErrorBoundary } from "~/components/CapErrorBoundary";
import { t } from "~/components/I18nProvider";

import { CAP_PREVIOUS_VERSIONS_URL } from "~/utils/download-links";

const WINDOW_SIZE = { width: 700, height: 540 } as const;

export default function Settings(props: RouteSectionProps) {
	const [version] = createResource(() => getVersion());

	onMount(() => {
		const currentWindow = getCurrentWindow();

		currentWindow.setSize(
			new LogicalSize(WINDOW_SIZE.width, WINDOW_SIZE.height),
		);
	});

	return (
		<div class="flex-1 flex flex-row divide-x divide-gray-3 text-[0.875rem] leading-[1.25rem] overflow-y-hidden">
			<div class="flex flex-col h-full bg-gray-2">
				<ul class="min-w-[12rem] h-full p-[0.625rem] space-y-1 text-gray-12">
					<For
						each={[
							{
								href: "general",
								name: t("nav.general"),
								icon: IconCapSettings,
							},
							{
								href: "hotkeys",
								name: t("nav.shortcuts"),
								icon: IconCapHotkeys,
							},
							{
								href: "recordings",
								name: t("nav.recordings"),
								icon: IconLucideSquarePlay,
							},
							{
								href: "screenshots",
								name: t("nav.screenshots"),
								icon: IconLucideImage,
							},
							// {
							// 	href: "integrations",
							// 	name: t('nav.integrations'),
							// 	icon: IconLucideUnplug,
							// },

							{
								href: "experimental",
								name: t("nav.experimental"),
								icon: IconCapSettings,
							},
							{
								href: "feedback",
								name: t("nav.feedback"),
								icon: IconLucideMessageSquarePlus,
							},
							{
								href: "changelog",
								name: t("nav.changelog"),
								icon: IconLucideBell,
							},
						].filter(Boolean)}
					>
						{(item) => (
							<li>
								<A
									href={item.href}
									activeClass="bg-gray-5 pointer-events-none"
									class="rounded-lg h-[2rem] hover:bg-gray-3 text-[13px] px-2 flex flex-row items-center gap-[0.375rem] transition-colors"
								>
									<item.icon class="opacity-60 size-4" />
									<span>{item.name}</span>
								</A>
							</li>
						)}
					</For>
				</ul>
				<div class="p-[0.625rem] text-left flex flex-col">
					<Show when={version()}>
						{(v) => (
							<div class="mb-2 text-xs text-gray-11 flex flex-col items-start gap-0.5">
								<span>v{v()}</span>
								<button
									type="button"
									class="text-gray-11 hover:text-gray-12 underline transition-colors"
									onClick={() => shell.open(CAP_PREVIOUS_VERSIONS_URL)}
								>
									View previous versions
								</button>
							</div>
						)}
					</Show>
				</div>
			</div>
			<div class="overflow-y-hidden flex-1 animate-in">
				<CapErrorBoundary>
					<Suspense>{props.children}</Suspense>
				</CapErrorBoundary>
			</div>
		</div>
	);
}
