namespace FieldTester.SyncAgent.SettingsResolution;

public interface ISettingResolver
{
    string Provider { get; }
    Task<ResolvedLocalSystemSettings> ResolveAsync(
        string localSettingFilePath,
        CancellationToken cancellationToken);
}
