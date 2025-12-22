def get_pgen(stem=False):
    if stem:
        return str(
            Path(config.get("pgen_src_path"), Path(config.get("pgen_template")).stem)
        )
    return str(Path(config.get("pgen_src_path"), config.get("pgen_template")))


def get_pvar(stem=False):
    if stem:
        return str(
            Path(config.get("pgen_src_path"), Path(config.get("pvar_template")).stem)
        )
    return str(Path(config.get("pgen_src_path"), config.get("pvar_template")))


def get_chromosomes():
    return [i for i in range(1, 23)]


def ws_path(file_path):
    return str(Path(config.get("workspace_path"), file_path))


def dest_path(file_path):
    return str(Path(config.get("dest_path"), file_path))
