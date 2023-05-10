# Changelog

## 2023-05-11: Initial Kinetic Update

This release is a major upgrade from the original version by @sjones4, without
which this would not have been possible.

- `entities.xml` has seen several major changes.

  - Certain assumptions made six years ago about which pages to select no longer
    hold true. Simply selecting on `property[@name='historicalVersions']`
    excluded between 5 and 20% of our pages because of internal changes in
    Confluence (the "new editor" has been released and is now the default, but
    pages must be converted explicitly).

    The page selection criteria is now to select any non-`draft` page that
    either:

    - has `collection[@name='historicalVersions']`, **or**
      - whose `id` is not present in any page's
        `collection[@name='historicalVersions']/element/id`, **and**
      - whose `id` is not present in any non-`draft` page's
        `property[@name='originalVersionId']`

    If this were any other company's product, `contentStatus` would have more
    values than `current` and `draft` so that older pages do not have the
    `current` status. Being able to select the most recent versions of pages
    with `object[@class='Page' and property[@name='ContentStatus']='current']`
    would be _so_ much faster than the multiply recursive lookup we do now.

    The logic for this can be seen on `entities.xsl:245–257` and
    `entities.xsl:274–285`.

  - Improved title-to-filename conversion with a set of function templates,
    `to-lowercase`, `clean-filename`, and `page-filename`. More characters are
    excluded (`` `%'() ``) from filename conversion and _only_ space and `/` are
    replaced with `-`. The rest are removed according to `translate()` XSLT
    spec. Title to filename conversion is now always done on the page's
    lowercase title (so a page "Foo Bar" will have a page filename of
    "foo-bar").

  - Removed the `space` and `space-category` parameters. Added `dtd-path` and
    `debug` parameters.

  - Modified the `page` output (this required a number of changes to
    `page.xsl`).

    - Added `<created/>` (using `creator` and `creationDate` properties) and
      `<last-modified/>` (using `lastModifier` and `lastModificationDate`
      properties) tags based on that have `<by/>` and `<at/>` attributes.
      The `<by/>` values are found in the `entites.xml` file to map the
      appropriate user identifier (which will usually be the email address).

      - `<last-modified/>` is omitted if the `creationDate` and
        `lastModificationDate` are the same.

      - The page filename is now included in the page as `<page-filename/>`.

    - Added a `<parent>` object lists to the output template. If the current
      page has a parent, then parents will be generated _in breadcrumb_ order.
      That is, if Confluence shows the breadcrumbs `A > B > C` on page `D`,
      then the parents list will be:

      ```xml
      <parent>
        <title>A</title>
        <filename>a</title>
      </parent>
      <parent>
        <title>B</title>
        <filename>b</title>
      </parent>
      <parent>
        <title>C</title>
        <filename>c</title>
      </parent>
      ```

      The filenames are transformed through `page-filename`.

    - Modified the `<space/>` tag from being just a string value to a more
      structured value describing the space, from `object[@class='Space']`. The
      fields are:

      - `<title/>`: The string title of the space
      - `<description/>`: The string description of the space.
      - `<path/>`: A `clean-filename` transformation of the space title.
      - `<key/>`: The space key.
      - `<lower-key`>: The space lowercase key.

    - Page labels are now discovered and attached to the `<page>` as additional
      `<category>` entries. With the removal of the `space-category` parameter,
      this category entry is also removed. Labels that belong to the `my`
      namespace are skipped, as are any namespace starting with
      `com.atlassian.`. `team`- and `global`-namespaced labels are rendered as
      is, and all other labels are rendered as `namspace:name`.

  - Changed the `image-mapping.xml` output file to include a useful filename in
    addition to the attachment ID and the title. This allows the use of
    a Markdown URL that is _safe_.

- `image-mappings.xsl` has seen mostly some logic cleanup and expansion to
  support new generation parameters, `input-path`, `output-path`, and `debug`.

- `page.xsl` has seen the most changes, but most of the changes are in order to
  recognize previously unsupported content, or to deal with some particularly
  nasty code examples seen in our code.

  - Unnecessary `<xsl:copy>` tags have been removed.

  - When processing, `page.xsl` now will read data from both
    `$output-path/image-mappings.xml` and `$input-path/entities.xml` to ensure
    that attachment links use the correct file path (rather than re-transforming
    the title into the name) and that user references are replaced with identity
    strings rather than omitted.

  - Some patterns will be serialized as XML using `match="*" mode="serialize"`.
    These are mostly for cases where the transforms do not support specific
    Confluence macros and they are put in an HTML comment.

  - `h1-6` nodes are now better matched and are explicitly pushed down one
    level, such that `<h1/>` produces `##` (a Markdown `<h2/>`) as the page
    `<title/>` is the only `<h1/>` to be present.

    - There is a special case where Confluence macros may be included in
      headers, in which case the header is ignored.

  - Additional `table` cases have been added:

    - Tables that use column headings (`<table><tr><th/><td/></tr></table>`) are
      rendered as Markdown lists.

    - Tables that follow the normal Markdown table format
      (`<table><tr><th/></tr><tr><td/></tr></table>`) are rendered as usual.

    - Tables without headers in the first row get a blank row.

    - Tables that explicitly do not follow one of these patterns are serialized
      as HTML.

  - User links are rendered as `@{user-identity-value}` where the user identity
    value is found in the source `entities.xsl`.

  - Additional confluence page link cases have been added

    | `$confluence-url` | space-key | link body | result                                            |
    | ----------------- | --------- | --------- | ------------------------------------------------- |
    | ~                 | current   | present   | `[link-body](clean-page-filename)`                |
    | ~                 | missing   | present   | `[link-body](clean-page-filename)`                |
    | ~                 | missing   | missing   | `[page-title](clean-page-filename)`               |
    | set               | different | present   | `[space-key: link-body](search-url)`              |
    | set               | different | missing   | `[space-key: page-title](search-url)`             |
    | missing           | different | ~         | `Page "page-title" in Confluence Space space-key` |

    The `search-url` value is `$confluence-url/wiki/search?spaces=space-key&text=page-title`.

  - Task lists are rendered as GitHub Flavoured Markdown task lists:

    ```markdown
    - [ ] task
    - [x] completed task
    ```

  - The following Confluence object types are skipped:

    - Placeholders
    - Anchors
    - Details marked as `hidden`.

  - The following Confluence object types are always serialized in an HTML
    comment:

    - Attachments
    - Blog Post lists
    - Children
    - Content Report
    - Create from Template
    - Details Summaries
    - Gliffy
    - Page Trees
    - Recently Updated
    - Related Content by Label
    - Tasks Report

  - Details objects with rich text bodies render the rich text body. Otherwise,
    they are rendered serialized in an HTML comment.

  - Info content objects are rendered. At the moment, only the `ℹ` (info)
    decoration is supported.

  - `iframe` objects are rendered both as the iframe and as a comment.

  - Status lozenge objects render just the status type.

  - Code blocks with title attributes are rendered inside a `details`/`summary`
    construct.

  - JIRA ticket links prefer rendering with the parameter `$jira-url` over the
    server URL listed in the content (which is often blank).

  - Date/Time objects render the inner timestamp value.

  - Front matter generation has been added.

- `page.dtd` has been updated to add `&lambda;` support and to force `&nbsp;` to
  generate a regular space character.
