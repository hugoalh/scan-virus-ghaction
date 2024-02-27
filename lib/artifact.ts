import { DefaultArtifactClient as GitHubActionsArtifactClient, type DownloadArtifactResponse as GitHubActionsArtifactDownloadResponse } from "@actions/artifact";
export interface SVGHAImportArtifactParameters {
	id: number;
	path: string;
}
export function importArtifact({ id, path }: SVGHAImportArtifactParameters): Promise<GitHubActionsArtifactDownloadResponse> {
	return new GitHubActionsArtifactClient().downloadArtifact(id, { path });
}
