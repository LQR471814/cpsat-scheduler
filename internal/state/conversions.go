package state

import (
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"
)

func SQLTimeToProto(t sql.NullTime) *timestamppb.Timestamp {
	if !t.Valid {
		return nil
	}
	return timestamppb.New(t.Time)
}

func ProtoTimeToSQL(t *timestamppb.Timestamp) sql.NullTime {
	if t == nil {
		return sql.NullTime{}
	}
	return sql.NullTime{
		Time:  t.AsTime(),
		Valid: true,
	}
}

// 0 is null sentinel for costs.
func SQLInt64ToProto(v sql.NullInt64) int64 {
	if !v.Valid {
		return 0
	}
	return v.Int64
}

// 0 is null sentinel for costs.
func ProtoInt64ToSQL(v int64) sql.NullInt64 {
	if v == 0 {
		return sql.NullInt64{}
	}
	return sql.NullInt64{
		Int64: v,
		Valid: true,
	}
}

// converts a time.Time to a profile time in terms of the atomic unit.
// rounds down to the nearest atomic unit.
func RealTimeToProfileTime(t sql.NullTime, profile db.Profile) sql.NullInt64 {
	if !t.Valid {
		return sql.NullInt64{Valid: false}
	}
	duration := t.Time.Sub(profile.UniverseStart)
	profileTime := duration / (time.Duration(profile.AtomicTimescaleDuration) * time.Second)
	return sql.NullInt64{
		Valid: true,
		Int64: int64(profileTime),
	}
}

// converts a profile time int64 to a time.Time.
func ProfileTimeToRealTime(profileTime sql.NullInt64, profile db.Profile) sql.NullTime {
	if !profileTime.Valid {
		return sql.NullTime{Valid: false}
	}
	duration := time.Duration(profile.AtomicTimescaleDuration) * time.Second * time.Duration(profileTime.Int64)
	return sql.NullTime{
		Valid: true,
		Time:  profile.UniverseStart.Add(duration),
	}
}
