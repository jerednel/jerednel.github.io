---
layout: post
title:  "The analytics/data science pipeline"
date:   2020-04-30 16:31:06 -0500
categories: datascience
---

# The modern analytics org

I've been thinking a lot lately about how analytics fits into the ecosystem for your standard organization and reflecting on my own experiences when working in analytics in-house.  I believe that the scope of analytics has evolved considerably over time due to greater exposure to data science and machine learning ideas.

This evolution of analytics has led to a broader range of skills required to complete the job.  You know need to know how to use APIs to pull data from 3rd party sources, use a language like Python or Julia to contort the data into a usable format.  Then you need to be comfortable with basic infrastructure and SQL to house the data you are creating, then domain-specific libraries in either Python (e.g. sklearn, Prophet) or R (e.g. statsmodels, ggplot2) to run analyses over this data.  Finally you need to communicate these results to stakeholders so obviously you'll need to be an expert in dashboarding and data visualization as well.

While I can personally attest to being comfortable in all of the above, I would liken it to being a generalist in engineering combined with a generalist statistician that can use visualization tools.  This means you don't quite fit anywhere and are sort of on an island between worlds.

## An Island

For small to medium-sized organizations, analytics is typically an island.  This island is all alone in an ocean between the country of Engineering and the continent of what I'll just refer to as "Business".  

Infrastructure teams often preoccupy themselves with devops and building out scalable data warehouses, but there are often needs from the business side to understand data that doesn't come cleanly so the analyst will inevitable code a ETL that sits outside of the world of infra and before you know it they get comfortable doing so and have dozens of serverless cloud functions running that are ETLing data from A to B to C for the purpose of joining data sources together!

On the business side, we never know the specifics of the campaigns as well as the teams running them so we have to do our best to infer things and ask the right questions to get the expert knowledge required to make decisions and conclusions about the data we are assessing.

## A better way?

Maybe all of this is just an inevitable side effect of being a hybrid-role in a world of specialists.  Maybe we have to just accept that we will have to have subclusters of data stores for analytical purposes that feed off of the main data warehouses.  And we'll have to accept that we will always be slightly behind the business owners in terms of our understanding of campaigns and catch-up when it comes to providing context to data we are looking at.

But I think there exists a world in which data is involved in both worlds in an official capacity. I propose a model for an analytics org that sees our analytical subclusters merged into the infrastructure pipeline to subject it to the same rigor and QA.  This model also requires participation on the business side in an official capacity to play a role in planning and executing on campaigns and objectives.

This is a tough job for an individual alone but with a team with a lead that sits in on sprint planning sessions with an infrastructure team as well as marketing that can then guide direct reports who check code into the main team's codebase while attending marketing and sales meetings, I think this is possible.  And I think it is necessary if the role of analytics continues to expand.
