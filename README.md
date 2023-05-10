# Convert a Confluence Space to GitHub Flavoured Markdown

This project will convert an XML-format Confluence space export to GitHub
Flavoured Markdown pages suitable for placement in a normal code repository.

This differs from the upstream [sjones4/confluence-to-github][upstream] in that
it does not use `[[WikiLink]]` format for links between pages, which means it is
_most likely_ no longer suitable for placement in a Gollum wiki.

Thanks to Steve Jones for the excellent starting point. No thanks to the various
XSLT committees for the insomnia obtained while adding features.

## Requirements

- [xsltproc][] must be installed.

  - Debian/Ubuntu: `apt-get install xsltproc` or `apt install xsltproc`.
  - Fedora derivatives: `dnf install libxslt`
  - Arch derivatives: `pacman -S libxslt`
  - macOS
    - Homebrew: `brew install libxslt`
    - MacPorts: `sudo oprt install libxslt`

- An unzipped Confluence XML space export.

  - Navigate to `Space Tools > Content Tools > Export`.
  - Choose `XML` format.
  - After export is complete, download it from the provided link.
  - Unzip the archive. Note where the contents were unzipped.

    - Tip: if you’re only doing this once, you can unzip the archive directly in
      this repository's directory.

- On Windows, `bash`, `mv`, and `cp` should be available (it is recommended that
  you run this under WSL2).

## Running the Export

Once you have unzipped the Confluence XML space export, you can run the
`generate` script. As the extraction step can be quite slow, this only needs to
be done once (or whenever the export is unzipped again).

By default, the `generate` script expects `entities.xml` to be present in the
current directory and will output the converted pages to `out/wiki`.

### Example

```console
$ ./generate
Input          : ./entities.xml
Output         : out
Steps
        Extract: true
     Image Copy: true
  Convert Pages: true

Extracting page XML and image mapping
Pages extracted.

Copying images from attachments
Images copied.

Converting pages to markdown
Pages converted.
```

After conversion, it is strongly recommended that you run at last one pass of
a Markdown formatter (such as [Prettier][]) over the generated Markdown files.
Some of the files need enough formatting that we have seen two passes required.

```console
$ prettier -w out/wiki && prettier -w out/wiki
```

## Export Options

There are a few useful export options. The one that should be used most
frequently is `--confluence-url`.

### `--confluence-url`, `-u`

Sets the URL for Confluence links. This should be the root URL, as the
transformation scripts will add `/wiki` as required.

### `--jira-url`, `-j`

Sets the URL for JIRA links. Defaults to the Confluence URL. The transformation
scripts will add `/browse` as required for ticket links.

### `--output`, `-o`

Sets the conversion output path.

### `--input`, `-i`

Sets the export archive input path.

### `--skip-extract`, `-E`

Skip the page extraction and image mapping step.

### `--skip-images`, `-I`

Skip the image copy step.

### `--skip-markdown`, `-M`

Skip the page conversion step.

### `--force`, `-f`

Force processing.

### `--debug`, `-d`

Enable debug output. Can be repeated to increase debug level.

#### Debug Levels

| Level | Flags    | Meaning                                                                                                                                    |
| ----- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 0     |          | No debug logging.                                                                                                                          |
| 1     | -d       | Tracing will be enabled to show the parameters to `xsltproc`.                                                                              |
| 2     | -d -d    | The output of the image copy mapping script will be printed before execution. Unless `--force` is provided, confirmation will be required. |
| 3     | -d -d -d | `xsltproc` verbose output will be enabled and the output will be saved in `OUTPUT_PATH/log`. This logging is very verbose.                 |

[xsltproc]: https://gitlab.gnome.org/GNOME/libxslt/-/wikis/home
[upstream]: https://github.com/sjones4/confluence-to-github
[prettier]: https://prettier.io
