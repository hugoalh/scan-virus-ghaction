export class SVGHAStatistic {
    discoverElement = 0n;
    discoverSize = 0n;
    foundAnyElement = 0n;
    foundAnySize = 0n;
    foundClamAVElement = 0n;
    foundClamAVSize = 0n;
    foundYARAElement = 0n;
    foundYARASize = 0n;
    selectAnyElement = 0n;
    selectAnySize = 0n;
    selectClamAVElement = 0n;
    selectClamAVSize = 0n;
    selectYARAElement = 0n;
    selectYARASize = 0n;
    constructor(...externals) {
        for (const external of externals) {
            this.discoverElement += external.discoverElement;
            this.discoverSize += external.discoverSize;
            this.foundAnyElement += external.foundAnyElement;
            this.foundAnySize += external.foundAnySize;
            this.foundClamAVElement += external.foundClamAVElement;
            this.foundClamAVSize += external.foundClamAVSize;
            this.foundYARAElement += external.foundYARAElement;
            this.foundYARASize += external.foundYARASize;
            this.selectAnyElement += external.selectAnyElement;
            this.selectAnySize += external.selectAnySize;
            this.selectClamAVElement += external.selectClamAVElement;
            this.selectClamAVSize += external.selectClamAVSize;
            this.selectYARAElement += external.selectYARAElement;
            this.selectYARASize += external.selectYARASize;
        }
    }
}
