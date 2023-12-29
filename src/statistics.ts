export class SVGHAStatistics {
	foundSessions: string[] = [];
	issues: string[] = [];
	sumDiscoverElement = 0n;
	sumDiscoverSize = 0n;
	sumFoundAnyElement = 0n;
	sumFoundAnySize = 0n;
	sumFoundClamAVElement = 0n;
	sumFoundClamAVSize = 0n;
	sumFoundYARAElement = 0n;
	sumFoundYARASize = 0n;
	sumSelectAnyElement = 0n;
	sumSelectAnySize = 0n;
	sumSelectClamAVElement = 0n;
	sumSelectClamAVSize = 0n;
	sumSelectYARAElement = 0n;
	sumSelectYARASize = 0n;
	constructor(...o: SVGHAStatistics[]) {
		for (const i of o) {
			this.foundSessions.push(...i.foundSessions);
			this.issues.push(...i.issues);
			this.sumDiscoverElement += i.sumDiscoverElement;
			this.sumDiscoverSize += i.sumDiscoverSize;
			this.sumFoundAnyElement += i.sumFoundAnyElement;
			this.sumFoundAnySize += i.sumFoundAnySize;
			this.sumFoundClamAVElement += i.sumFoundClamAVElement;
			this.sumFoundClamAVSize += i.sumFoundClamAVSize;
			this.sumFoundYARAElement += i.sumFoundYARAElement;
			this.sumFoundYARASize += i.sumFoundYARASize;
			this.sumSelectAnyElement += i.sumSelectAnyElement;
			this.sumSelectAnySize += i.sumSelectAnySize;
			this.sumSelectClamAVElement += i.sumSelectClamAVElement;
			this.sumSelectClamAVSize += i.sumSelectClamAVSize;
			this.sumSelectYARAElement += i.sumSelectYARAElement;
			this.sumSelectYARASize += i.sumSelectYARASize;
		}
	}
}
