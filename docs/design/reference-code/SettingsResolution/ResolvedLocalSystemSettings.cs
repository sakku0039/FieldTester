namespace FieldTester.SyncAgent.SettingsResolution;

public sealed record ResolvedLocalSystemSettings(
    string Provider,
    string EntrySettingFilePath,
    string ServerFolderPath,
    string SecondarySettingFilePath,
    ResolvedSqlSettings Sql,
    ResolvedDatabaseNames Databases,
    ResolvedFactorySettings Factory,
    string ConfigurationFingerprint);

public sealed record ResolvedSqlSettings(
    string ProviderName,
    string ServerName,
    string AuthenticationMode,
    string UserId,
    string Password,
    bool Encrypt,
    bool TrustServerCertificate)
{
    public override string ToString() =>
        $"Server={ServerName};AuthenticationMode={AuthenticationMode};UserId={UserId};Password=***";
}

public sealed record ResolvedDatabaseNames(
    string Master,
    string ShippingData,
    string? QualityData,
    string? CommonSettings,
    IReadOnlyDictionary<string, string> OptionalDatabases);

public sealed record ResolvedFactorySettings(
    string InitialFactoryCode,
    bool FactoryCodeEnabled);
