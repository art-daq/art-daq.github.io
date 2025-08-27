import re
import argparse
import json
from jinja2 import Environment, FileSystemLoader
from pathlib import Path
from datetime import datetime, UTC

def generate_site(json_input_path):
    """Render html files from templates to generate the site."""
    with open(json_input_path, 'r') as f:
        repos = json.load(f)

    env = Environment(loader=FileSystemLoader("templates"))
    index_template = env.get_template("index_template.html")

    total_issues = sum(repo["open_issues"] for repo in repos)
    total_prs = sum(repo["open_prs"] for repo in repos)

    total_repos = len(repos)
    passing_repos = sum(
        1 for repo in repos
        if repo.get("build_develop", {}).get("conclusion") == "success"
    )

    passing_percentage = round((passing_repos / total_repos) * 100, 1) if total_repos else 0

    last_updated=datetime.now(UTC).strftime("%Y-%m-%d %H:%M UTC")
    workflow_badges = [
    {
        "image": "https://github.com/art-daq/.github/actions/workflows/otsdaq-lcov.yml/badge.svg",
        "link": "https://github.com/art-daq/.github/actions/workflows/otsdaq-lcov.yml",
        "alt": "Create otsdaq LCOV coverage report"},
    {
        "image": "https://github.com/art-daq/.github/actions/workflows/artdaq-lcov.yml/badge.svg",
        "link": "https://github.com/art-daq/.github/actions/workflows/artdaq-lcov.yml",
        "alt": "Create artdaq LCOV coverage report"},
    {
        "image": "https://github.com/art-daq/daq-docker/actions/workflows/alma9-spack-base.yaml/badge.svg",
        "link": "https://github.com/art-daq/daq-docker/actions/workflows/alma9-spack-base.yaml",
        "alt": "Build alma9-spack docker image"},
    {
        "image": "https://github.com/art-daq/daq-docker/actions/workflows/artdaq-spack-selfhosted.yaml/badge.svg",
        "link": "https://github.com/art-daq/daq-docker/actions/workflows/artdaq-spack-selfhosted.yaml",
        "alt": "Build artdaq-spack docker image (self hosted)"}, 
    {
        "image": "https://github.com/art-daq/daq-docker/actions/workflows/otsdaq-spack-selfhosted.yaml/badge.svg",
        "link": "https://github.com/art-daq/daq-docker/actions/workflows/otsdaq-spack-selfhosted.yaml",
        "alt": "Build otsdaq-spack docker image (self hosted)"},
    ]
    
    # Content of the index page
    context = {
        "repos": repos,
        "last_updated": last_updated,
        "total_issues": total_issues,
        "total_prs": total_prs,
        "passing_percentage": passing_percentage,
        "workflow_badges": workflow_badges,
    }

    index_template = env.get_template("index_template.html")
    index_html = index_template.render(context)
    index_path = Path("site/index.html")
    index_path.parent.mkdir(parents=True, exist_ok=True)
    index_path.write_text(index_html)

    print('Done')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate CI HTML site from a JSON summary file.")
    parser.add_argument("--json_input", required=True, help="Path to the JSON file containing CI summary data. See collect-ci-metrics.sh.")
    args = parser.parse_args()

    generate_site(args.json_input)
