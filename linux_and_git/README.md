# Linux and Git

This folder contains two shell scripts for working with local data files.

## 1) ETL script: script.sh

The first script is an ETL job that:

- downloads a government finance dataset from the internet
- saves the raw file in the `raw` folder
- cleans and transforms the CSV data into a more usable format
- stores the transformed output in the `Transformed` folder
- copies the final result into the `Gold` folder

It automatically creates the needed folders if they do not already exist:

- `raw`
- `Transformed`
- `Gold`

The script also standardizes column names before saving the final file as `2023_year_finance.csv`.

### Run the ETL script

```bash
chmod +x script.sh
./script.sh
```

### Schedule it to run every day at 12:00 AM

Open the cron table:

```bash
crontab -e
```

Then add this line:

```bash
0 0 * * * /cde-projects/linux_and_git/script.sh
```

This will run the ETL process every day at 12AM.

To verify the cron job:

```bash
crontab -l
```

---

## 2) JSON/CSV mover: second_script.sh

The second script is much simpler. It does not perform ETL.

Its purpose is to move JSON and CSV files from the `sources` directory into a `json_and_csv` folder.

### Run the file mover

```bash
chmod +x second_script.sh
./second_script.sh
```

### What it does

- checks `./sources`
- creates `./json_and_csv` if needed
- moves any `.csv`, `.CSV`, `.json`, or `.JSON` files into that folder

This script is used only to organize or transfer the data files, not to transform them.
