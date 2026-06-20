type SegmentParam<Segment extends string> =
	Segment extends `[...${infer Param}]`
		? { [Key in Param]: string[] }
		: Segment extends `[[...${infer Param}]]`
			? { [Key in Param]?: string[] }
			: Segment extends `[${infer Param}]`
				? { [Key in Param]: string }
				: {};

type PathParams<Path extends string> = string extends Path
	? Record<string, string | string[] | undefined>
	: Path extends `${infer Head}/${infer Tail}`
		? SegmentParam<Head> & PathParams<Tail>
		: SegmentParam<Path>;

export type PageProps<Path extends string = string> = {
	params: Promise<PathParams<Path>>;
	searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export type RouteContext<Path extends string = string> = {
	params: Promise<PathParams<Path>>;
};
