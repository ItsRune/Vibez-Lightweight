--!nocheck
export type BenchmarkProfiler = {
	start: (label: string) -> (),
	stop: (t: number?) -> (),
}
export type BenchFunction<Parameter> = (
	profiler: BenchmarkProfiler,
	parameter: Parameter
) -> ()
export type BenchModule<Parameter> = {
	ParameterGenerator: (() -> Parameter)?,
	BeforeAll: (() -> ())?,
	AfterAll: (() -> ())?,
	BeforeEach: (() -> ())?,
	AfterEach: (() -> ())?,	
	Functions: { [string]: BenchFunction<Parameter> },
}