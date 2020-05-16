// Use this file to write queries to test your data connector
let
    Lähde = OuraCloudConnector.Contents(),
    Readiness1 = Lähde{[Name="Readiness"]}[Data],
    data = Table.ExpandListColumn(Readiness1, "readiness"),
    data1 = Table.ExpandRecordColumn(data, "readiness", {"period_id", "score", "score_activity_balance", "score_hrv_balance", "score_previous_day", "score_previous_night", "score_recovery_index", "score_resting_hr", "score_sleep_balance", "score_temperature", "summary_date"}, {"period_id", "score", "score_activity_balance", "score_hrv_balance", "score_previous_day", "score_previous_night", "score_recovery_index", "score_resting_hr", "score_sleep_balance", "score_temperature", "summary_date"})
in
    data1