package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
)

func (s server) ListProfiles(ctx context.Context, in *api.ListProfilesRequest) (res *api.ListProfilesResponse, err error) {
	profiles, err := s.db.ListProfiles(ctx)
	if err != nil {
		return
	}
	res = &api.ListProfilesResponse{
		Entries: make([]*api.Profile, len(profiles)),
	}
	for i, p := range profiles {
		res.Entries[i] = &api.Profile{
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

func (s server) CreateProfile(ctx context.Context, in *api.CreateProfileRequest) (res *api.CreateProfileResponse, err error) {
	_, err = s.db.CreateProfile(ctx, db.CreateProfileParams{
		Name:                    in.Name,
		AtomicTimescaleDuration: in.AtomicTimescale.Seconds,
		UniverseStart:           state.ProtoTimeToSQL(in.UniverseStart).Time,
		PertGenChoices:          sql.NullInt64{Valid: true, Int64: in.GenPertChoices},
	})
	if err != nil {
		return
	}
	res = &api.CreateProfileResponse{}
	return
}

func (s server) RemoveProfile(ctx context.Context, in *api.RemoveProfileRequest) (res *api.RemoveProfileResponse, err error) {
	err = s.db.DeleteProfile(ctx, in.Id)
	if err != nil {
		return
	}
	res = &api.RemoveProfileResponse{}
	return
}
