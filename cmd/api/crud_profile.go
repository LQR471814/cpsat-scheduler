package main

import (
	"context"
	"cpsat-scheduler/internal/proto/apipb"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"fmt"
)

func (s server) ListProfiles(ctx context.Context, in *apipb.ListProfilesRequest) (res *apipb.ListProfilesResponse, err error) {
	profiles, err := s.db.ListProfiles(ctx)
	if err != nil {
		err = fmt.Errorf("db ListProfiles: %w", err)
		return
	}
	res = &apipb.ListProfilesResponse{
		Entries: make([]*apipb.Profile, len(profiles)),
	}
	for i, p := range profiles {
		res.Entries[i] = &apipb.Profile{
			Id:              p.ID,
			Name:            p.Name,
			AtomicTimescale: state.SQLDurationToProto(p.AtomicTimescaleDuration),
			UniverseStart:   state.SQLTimeToProto(sql.NullTime{Valid: true, Time: p.UniverseStart}),
		}
		if p.PertGenChoices.Valid {
			res.Entries[i].GenPertChoices = &p.PertGenChoices.Int64
		}
	}
	return
}

func (s server) CreateProfile(ctx context.Context, in *apipb.CreateProfileRequest) (res *apipb.CreateProfileResponse, err error) {
	_, err = s.db.CreateProfile(ctx, db.CreateProfileParams{
		Name:                    in.Name,
		AtomicTimescaleDuration: in.AtomicTimescale.Seconds,
		UniverseStart:           state.ProtoTimeToSQL(in.UniverseStart).Time,
		PertGenChoices:          sql.NullInt64{Valid: true, Int64: in.GenPertChoices},
	})
	if err != nil {
		err = fmt.Errorf("db CreateProfile: %w", err)
		return
	}
	res = &apipb.CreateProfileResponse{}
	return
}

func (s server) RemoveProfile(ctx context.Context, in *apipb.RemoveProfileRequest) (res *apipb.RemoveProfileResponse, err error) {
	err = s.db.DeleteProfile(ctx, in.Id)
	if err != nil {
		err = fmt.Errorf("db DeleteProfile: %w", err)
		return
	}
	res = &apipb.RemoveProfileResponse{}
	return
}
