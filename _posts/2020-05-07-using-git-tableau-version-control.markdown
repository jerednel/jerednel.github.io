---
layout: post
title:  "Use Git for Tableau version control"
date:   2020-04-30 16:31:06 -0500
categories: analytics
---

# Versioning in Tableau is difficult

But it doesn't have to be.  I work from a couple of different stations that cross operating systems and have found that simply initializing a git repo in my Tableau workbook directory then committing them solves for a lot of my issues.

My structure is simple. I have a directory dedicated to Tableau workbooks then subdirectories that branch off into separate visualizations.

```
\Tableau
--\marketing
--\sales
--\internal
```

I can maintain consistency over all of these.  Doing so is as easy as

```
cd \dev\tableau\
git init
git remote add origin yourgiturl
git add .
git commit -m "initial commit"
git push -u origin master
```

The only downside is that no you cannot take advantage of collaborative functionalities of Git.  What this does is act more like a storage facility.

*Tip*: If you are collaborating with another analyst on a workbook, figure out a convention for signaling that the workbook is checked-out to be worked on.  You cannot both edit the workbook.  The unfortunate downside is that this means you have to commit to signal to your colleagues that you are editing a workbook.
