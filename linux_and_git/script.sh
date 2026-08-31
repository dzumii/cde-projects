#!/bin/bash
cd "$(dirname "$0")" || exit 1
echo "Good to go!"
url="https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv"
raw_file_dir="./raw"
raw_file_name="2023_financial_data.csv"

transformed_dir="./Transformed"
transformed_file_name="2023_year_finance.csv"

final_dir="./Gold"

mkdir -p $raw_file_dir
mkdir -p $transformed_dir
mkdir -p $final_dir

wget -O $raw_file_dir/$raw_file_name $url

if [ -f "$raw_file_dir/$raw_file_name" ]; then
    echo "Download successful: $raw_file_dir/$raw_file_name"
else
    echo "Download failed."
fi

awk -F',' '
BEGIN {
    OFS=","
}

NR == 1 {
    for (i = 1; i <= NF; i++) {
        if ($i == "Variable_code") {
            $i = "variable_code"
        }

        if ($i == "year") year_col = i
        if ($i == "Value") value_col = i
        if ($i == "Units") units_col = i
        if ($i == "variable_code") variable_code_col = i
    }

    print "year", "Value", "Units", "variable_code"
    next
}

{
    print $year_col, $value_col, $units_col, $variable_code_col
}
' "$raw_file_dir/$raw_file_name" > "$transformed_dir/$transformed_file_name"

if [ -f "$transformed_dir/$transformed_file_name" ]; then
    echo "Transformation successful: $transformed_dir/$transformed_file_name"
else
    echo "Transformation failed."
fi

cp "$transformed_dir/$transformed_file_name" "$final_dir"

if [ -f "$final_dir/$transformed_file_name" ]; then
    echo "Copy successful: $final_dir/$transformed_file_name"
else
    echo "Copy failed."
fi

