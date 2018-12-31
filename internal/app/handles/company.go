package handles

import (
	"context"
	"errors"
	"fmt"

	"github.com/minchao/go-gcis/gcis"
)

type companyEvent struct {
	ID string `json:"id"`
}

type company struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

func HandleCompany(c companyEvent) (*company, error) {
	info, _, err := client.Company.GetBasicInformation(context.Background(),
		&gcis.CompanyBasicInformationInput{BusinessAccountingNO: c.ID})
	if err != nil {
		return nil, errors.New("unexpected error")
	}
	if info == nil {
		return nil, fmt.Errorf("cannot find company with ID: %s", c.ID)
	}

	return &company{
		ID:   info.BusinessAccountingNO,
		Name: info.CompanyName,
	}, nil
}
