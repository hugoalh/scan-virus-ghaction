import { DefaultArtifactClient as GitHubActionsArtifactClient } from "@actions/artifact";
export function importArtifact({ id, path }) {
    return new GitHubActionsArtifactClient().downloadArtifact(id, { path });
}
