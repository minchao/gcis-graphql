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

func HandleCompany(event companyEvent) (*company, error) {
	info, _, err := client.Company.GetBasicInformation(context.Background(),
		&gcis.CompanyBasicInformationInput{BusinessAccountingNO: event.ID})
	if err != nil {
		return nil, errors.New("unexpected error")
	}
	if info == nil {
		return nil, fmt.Errorf("cannot find company with ID: %s", event.ID)
	}

	return &company{
		ID:   info.BusinessAccountingNO,
		Name: info.CompanyName,
	}, nil
}

type searchEvent struct {
	Keyword string `json:"keyword"`
	Status  string `json:"status"`
	Offset  int    `json:"offset"`
	Limit   int    `json:"limit"`
}

type companies []*company

func HandleSearch(event searchEvent) (companies, error) {
	if event.Status == "" {
		event.Status = "01"
	}

	list := companies{}
	out, _, err := client.Company.SearchByKeyword(context.Background(),
		&gcis.CompanyByKeywordInput{
			CompanyName:   event.Keyword,
			CompanyStatus: event.Status,
			SearchOptions: gcis.SearchOptions{
				Top:  event.Limit,
				Skip: event.Offset,
			},
		})
	if err != nil {
		return nil, errors.New("unexpected error")
	}
	for _, info := range out {
		c := &company{
			ID:   info.BusinessAccountingNO,
			Name: info.CompanyName,
		}
		list = append(list, c)
	}

	return list, nil
}
