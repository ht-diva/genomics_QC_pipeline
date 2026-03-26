#!/usr/bin/env python3

import argparse
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser(
        description="Select best SNP per site. Keep singleton variants as they are; for multiallelic sites keep only the best biallelic SNP with highest MAF."
    )

    parser.add_argument("--afreq", required=True, help="PLINK2 .afreq file")
    parser.add_argument("--pvar", required=True, help="PLINK2 .pvar file")
    parser.add_argument("--output", required=True, help="Output file with variant IDs")

    return parser.parse_args()


def read_afreq(path):
    maf_dict = {}

    with open(path) as f:
        header = f.readline().lstrip("#").split()
        columns = {c: i for i, c in enumerate(header)}

        id_col = columns["ID"]

        if "ALT_FREQS" in columns:
            freq_col = columns["ALT_FREQS"]
        else:
            freq_col = columns["AFREQ"]

        for line in f:
            if not line.strip():
                continue

            s = line.split()
            vid = s[id_col]
            af = float(s[freq_col].split(",")[0])
            maf = min(af, 1 - af)
            maf_dict[vid] = maf

    return maf_dict


def read_pvar(path):
    variants = []

    with open(path) as f:
        for line in f:
            if line.startswith("#"):
                continue

            chrom, pos, vid, ref, alt = line.strip().split("\t")[:5]

            variants.append(
                {
                    "chrom": chrom,
                    "pos": pos,
                    "id": vid,
                    "ref": ref,
                    "alt": alt,
                }
            )

    return variants


def is_biallelic_snp(ref, alt):
    if "," in alt:
        return False

    if len(ref) != 1 or len(alt) != 1:
        return False

    bases = {"A", "C", "G", "T"}

    if ref not in bases or alt not in bases:
        return False

    return True


def select_best_variants(variants, maf_dict):
    sites = defaultdict(list)

    for v in variants:
        key = (v["chrom"], v["pos"])
        sites[key].append(v)

    keep = []

    for site, vars_at_site in sites.items():

        # If the position appears only once, keep it as it is
        # even if it is not a biallelic SNP.
        if len(vars_at_site) == 1:
            keep.append(vars_at_site[0]["id"])
            continue

        # If the position appears more than once, treat it as multiallelic
        # and keep only the best valid biallelic SNP.
        best_id = None
        best_maf = -1

        for v in vars_at_site:
            if not is_biallelic_snp(v["ref"], v["alt"]):
                continue

            maf = maf_dict.get(v["id"], -1)

            if maf > best_maf:
                best_maf = maf
                best_id = v["id"]

        if best_id is not None:
            keep.append(best_id)

    return keep


def write_output(ids, path):
    with open(path, "w") as f:
        for vid in ids:
            f.write(vid + "\n")


def main():
    args = parse_args()

    maf_dict = read_afreq(args.afreq)
    variants = read_pvar(args.pvar)
    best = select_best_variants(variants, maf_dict)
    write_output(best, args.output)


if __name__ == "__main__":
    main()