from pathlib import Path
import re
import unicodedata

import geopandas as gpd
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from matplotlib.cm import ScalarMappable
from matplotlib.patches import Patch




BASE_DIR = Path(__file__).resolve().parent

CSV_FILE = BASE_DIR / "Évolution de la production du blé dur.csv"

BOUNDARY_FILE = BASE_DIR / "Tunisia_gov" / "Tunisia_gov.shp"

OUTPUT_DIR = BASE_DIR / "Tunisia_wheat_evolution_outputs"



SELECTED_YEARS = [1982, 1997, 2000, 2010, 2018]


GOVERNORATE_FIELD = "shape1"

PRODUCTION_CMAP = "RdYlGn"   
MISSING_COLOR = "#D9D9D9"    
COVERED_COLOR = "#36A66A"   
BOUNDARY_COLOR = "white"

FIGURE_SIZE = (13, 6)




def normalize_name(value):
    """Standardize governorate names to make CSV/boundary matching easier."""
    if pd.isna(value):
        return ""

    text = str(value).strip().lower()
    text = text.replace("’", "'").replace("`", "'")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(
        char for char in text
        if not unicodedata.combining(char)
    )
    text = re.sub(r"[^a-z0-9]", "", text)

    aliases = {
        "benarous": "benarous",
        "benarousgovernorate": "benarous",
        "bensarous": "benarous",
        "elke f": "kef",
        "elkef": "kef",
        "lekef": "kef",
        "kef": "kef",
        "medenine": "medenine",
        "mednine": "medenine",
        "tataouine": "tatouine",
        "tatouine": "tatouine",
        "manouba": "manouba",
        "lamanouba": "manouba",
        "sidibouzid": "sidibouzid",
        "sidi": "sidi",
        "gabes": "gabes",
        "gabès": "gabes",
        "gafsa": "gafsa",
        "kebili": "kebili",
        "kébili": "kebili",
        "kasserine": "kasserine",
        "jendouba": "jendouba",
        "zaghouan": "zaghouan",
        "siliana": "siliana",
        "bizerte": "bizerte",
        "ariana": "ariana",
        "tunis": "tunis",
        "sfax": "sfax",
        "sousse": "sousse",
        "monastir": "monastir",
        "mahdia": "mahdia",
        "mehdia": "mahdia",
        "nabeul": "nabeul",
        "tozeur": "tozeur",
        "kairouan": "kairouan",
        "beja": "beja",
        "béja": "beja",
    }

    return aliases.get(text, text)



def find_governorate_field(gdf):
    if GOVERNORATE_FIELD is not None:
        if GOVERNORATE_FIELD not in gdf.columns:
            raise ValueError(
                f"The field '{GOVERNORATE_FIELD}' does not exist.\n"
                f"Available fields: {list(gdf.columns)}"
            )
        return GOVERNORATE_FIELD

    likely_names = [
        "name_1", "name", "governorate", "gouvernorat",
        "gov_name", "admin1", "adm1_name", "shapeName",
        "nom", "nom_gouv", "gouv_name"
    ]

    lower_to_original = {
        str(column).strip().lower(): column
        for column in gdf.columns
    }

    for candidate in likely_names:
        if candidate.lower() in lower_to_original:
            return lower_to_original[candidate.lower()]

    text_fields = [
        column for column in gdf.columns
        if column != gdf.geometry.name
        and (
            pd.api.types.is_object_dtype(gdf[column])
            or pd.api.types.is_string_dtype(gdf[column])
        )
    ]

    if len(text_fields) == 1:
        return text_fields[0]

    raise ValueError(
        "The script could not automatically identify the governorate-name "
        "field in Tunisia_gov.shp.\n"
        f"Available fields: {list(gdf.columns)}\n\n"
        "Set GOVERNORATE_FIELD near the beginning of the script to the "
        "correct field name."
    )




def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if not CSV_FILE.exists():
        raise FileNotFoundError(
            f"CSV not found:\n{CSV_FILE}\n"
            "Make sure the CSV is beside this Python script."
        )

    if not BOUNDARY_FILE.exists():
        raise FileNotFoundError(
            f"Shapefile not found:\n{BOUNDARY_FILE}\n\n"
            "Check that your folder is named 'Tunisia_gov' and that the "
            "main shapefile is named 'Tunisia_gov.shp'. The .shx, .dbf "
            "and .prj files should be in the same folder and have the "
            "same base name."
        )

    print("Reading CSV...")
    df = pd.read_csv(CSV_FILE, encoding="utf-8-sig")

    required = {"Date", "Gouvernorat", "Production"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(
            f"Missing CSV columns: {sorted(missing)}\n"
            f"Columns found: {list(df.columns)}"
        )

    df["Date"] = pd.to_numeric(df["Date"], errors="coerce")
    df["Production"] = pd.to_numeric(df["Production"], errors="coerce")
    df = df.dropna(
        subset=["Date", "Gouvernorat", "Production"]
    ).copy()

    df["Date"] = df["Date"].astype(int)
    df["name_key"] = df["Gouvernorat"].apply(normalize_name)

    available_years = sorted(df["Date"].unique().tolist())

    invalid_years = [
        year for year in SELECTED_YEARS
        if year not in available_years
    ]
    if invalid_years:
        raise ValueError(
            f"Selected years not found in CSV: {invalid_years}\n"
            f"Available years: {available_years}"
        )

    yearly_data = (
        df.groupby(["Date", "name_key"], as_index=False)
        .agg(
            Production=("Production", "sum"),
            CSV_Name=("Gouvernorat", "first")
        )
    )

    print("Reading Tunisia governorate boundaries...")
    boundaries = gpd.read_file(BOUNDARY_FILE)

    gov_field = find_governorate_field(boundaries)
    print(f"Governorate field detected: {gov_field}")
    print("Governorate names found in shapefile:")
    for value in sorted(boundaries[gov_field].dropna().astype(str).unique()):
        print("  -", value)

    boundaries = boundaries[
        boundaries.geometry.notna()
    ].copy()

    boundaries["name_key"] = boundaries[gov_field].apply(normalize_name)

    boundaries = boundaries.dissolve(
        by="name_key",
        as_index=False,
        aggfunc="first"
    )

    print("\nNumber of unique governorates in shapefile:", len(boundaries))
    print("Unique normalized shapefile names:")
    print(sorted(boundaries["name_key"].unique()))



    if boundaries.crs is None:
        raise ValueError(
            "The boundary shapefile has no defined CRS. "
            "Please define its CRS before running the script."
        )

    try:
        boundaries["geometry"] = boundaries.geometry.make_valid()
    except Exception:
        boundaries["geometry"] = boundaries.geometry.buffer(0)

    # Report names that cannot be matched.
    boundary_names = set(boundaries["name_key"])
    csv_names = set(yearly_data["name_key"])
    unmatched = sorted(csv_names - boundary_names)

    if unmatched:
        print("\nWARNING: These CSV governorate names were not matched:")
        for name in unmatched:
            original_names = yearly_data.loc[
                yearly_data["name_key"] == name, "CSV_Name"
            ].unique()
            print(f"  {name}: {list(original_names)}")
        print("Check the names in normalize_name() if necessary.")

    values = yearly_data.loc[
        yearly_data["Date"].isin(SELECTED_YEARS), "Production"
    ].dropna()

    vmin = float(values.min())
    vmax = float(values.max())
    if vmin == vmax:
        vmax = vmin + 1

    norm = Normalize(vmin=vmin, vmax=vmax)
    cmap = plt.get_cmap(PRODUCTION_CMAP)

    yearly_layers = {}
    coverage_stats = []

    for year in SELECTED_YEARS:
        data_year = yearly_data.loc[
            yearly_data["Date"] == year,
            ["name_key", "Production", "CSV_Name"]
        ].copy()

        layer = boundaries.merge(
            data_year,
            on="name_key",
            how="left"
        )

        layer["covered"] = layer["Production"].notna().astype(int)
        layer["year"] = year
        yearly_layers[year] = layer

       
        boundary_names = set(boundaries["name_key"])
        csv_names = set(data_year["name_key"])

        matched_names = boundary_names.intersection(csv_names)

        covered_count = len(matched_names)
        total_count = len(boundary_names)

        percent = covered_count / total_count * 100 if total_count else 0

        missing_names = sorted(boundary_names - csv_names)

        print(f"\nYear: {year}")
        print("Matched governorates:", sorted(matched_names))
        print("Missing governorates:", missing_names)
        print(f"Coverage: {covered_count}/{total_count}")
        percent = (
            covered_count / total_count * 100
            if total_count else 0
        )

        coverage_stats.append({
            "Year": year,
            "Covered_governorates": covered_count,
            "Total_governorates": total_count,
            "Coverage_percent": round(percent, 2)
        })

       
        export_layer = layer.drop(
            columns=["name_key"], errors="ignore"
        ).copy()

        export_layer = export_layer.rename(columns={
            gov_field: "Gov_name",
            "Production": "Prod",
            "CSV_Name": "CSV_name",
            "covered": "Cover",
        })

        shapefile_path = OUTPUT_DIR / f"production_{year}.shp"
        export_layer.to_file(
            shapefile_path,
            driver="ESRI Shapefile",
            encoding="UTF-8"
        )

        print(
            f"{year}: {covered_count}/{total_count} governorates covered "
            f"({percent:.1f}%)"
        )

    # Save coverage table.
    stats = pd.DataFrame(coverage_stats)
    stats.to_csv(
        OUTPUT_DIR / "coverage_statistics.csv",
        index=False,
        encoding="utf-8-sig"
    )

  

    fig, axes = plt.subplots(
        1,
        len(SELECTED_YEARS),
        figsize=FIGURE_SIZE,
        constrained_layout=True
    )

    if len(SELECTED_YEARS) == 1:
        axes = [axes]

    for ax, year in zip(axes, SELECTED_YEARS):
        layer = yearly_layers[year]

        no_data = layer[layer["Production"].isna()]
        has_data = layer[layer["Production"].notna()]

        if not no_data.empty:
            no_data.plot(
                ax=ax,
                color=MISSING_COLOR,
                edgecolor=BOUNDARY_COLOR,
                linewidth=0.45
            )

        if not has_data.empty:
            has_data.plot(
                ax=ax,
                column="Production",
                cmap=cmap,
                norm=norm,
                edgecolor=BOUNDARY_COLOR,
                linewidth=0.45
            )

        count = int(layer["covered"].sum())
        ax.set_title(
            f"{year}\nCovered: {count}/{len(layer)}",
            fontsize=11,
            fontweight="bold"
        )
        ax.set_axis_off()
        ax.set_aspect("equal")

    sm = ScalarMappable(norm=norm, cmap=cmap)
    sm.set_array([])

    cbar = fig.colorbar(
        sm,
        ax=axes,
        orientation="horizontal",
        fraction=0.055,
        pad=0.04,
        aspect=35
    )
    cbar.set_label("Durum wheat production (1000 qt)")

    fig.suptitle(
        "Evolution of durum wheat production across Tunisia",
        fontsize=14,
        fontweight="bold"
    )

    fig.savefig(
        OUTPUT_DIR / "production_evolution.png",
        dpi=300,
        bbox_inches="tight"
    )
    plt.close(fig)

  

    fig, axes = plt.subplots(
        1,
        len(SELECTED_YEARS),
        figsize=FIGURE_SIZE,
        constrained_layout=True
    )

    if len(SELECTED_YEARS) == 1:
        axes = [axes]

    for ax, year in zip(axes, SELECTED_YEARS):
        layer = yearly_layers[year]

        no_data = layer[layer["covered"] == 0]
        has_data = layer[layer["covered"] == 1]

        if not no_data.empty:
            no_data.plot(
                ax=ax,
                color=MISSING_COLOR,
                edgecolor="white",
                linewidth=0.45
            )

        if not has_data.empty:
            has_data.plot(
                ax=ax,
                color=COVERED_COLOR,
                edgecolor="white",
                linewidth=0.45
            )

        count = int(layer["covered"].sum())
        total = len(layer)
        percent = count / total * 100 if total else 0

        ax.set_title(
            f"{year}\n{count}/{total} ({percent:.1f}%)",
            fontsize=11,
            fontweight="bold"
        )
        ax.set_axis_off()
        ax.set_aspect("equal")

    legend_items = [
        Patch(
            facecolor=COVERED_COLOR,
            edgecolor="white",
            label="Covered (data available)"
        ),
        Patch(
            facecolor=MISSING_COLOR,
            edgecolor="white",
            label="Not covered (no data)"
        )
    ]

    fig.legend(
        handles=legend_items,
        loc="lower center",
        ncol=2,
        frameon=False
    )

    fig.suptitle(
        "Evolution of governorate coverage in the dataset",
        fontsize=14,
        fontweight="bold"
    )

    fig.savefig(
        OUTPUT_DIR / "governorate_coverage_evolution.png",
        dpi=300,
        bbox_inches="tight"
    )
    plt.close(fig)

   

    combined = boundaries.copy()

    for year in SELECTED_YEARS:
        one_year = yearly_data.loc[
            yearly_data["Date"] == year,
            ["name_key", "Production"]
        ].copy()

        one_year = one_year.rename(
            columns={"Production": f"p_{year}"}
        )

        combined = combined.merge(
            one_year,
            on="name_key",
            how="left"
        )

        combined[f"c_{year}"] = (
            combined[f"p_{year}"].notna().astype(int)
        )

    combined = combined.drop(
        columns=["name_key"], errors="ignore"
    )

    combined.to_file(
        OUTPUT_DIR / "coverage_evolution.gpkg",
        layer="governorate_coverage",
        driver="GPKG"
    )

    print("\nPROCESS COMPLETED SUCCESSFULLY")
    print(f"All results are in:\n{OUTPUT_DIR.resolve()}")
    print("\nFiles created:")
    print(" - production_evolution.png")
    print(" - governorate_coverage_evolution.png")
    print(" - coverage_statistics.csv")
    print(" - production_<YEAR>.shp (+ its sidecar files)")
    print(" - coverage_evolution.gpkg")


if __name__ == "__main__":
    main()
