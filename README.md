ICEBOXER
_over 5000 served_

![picture of the iceboxer](https://cloud.githubusercontent.com/assets/699550/5100358/75aa3366-6f73-11e4-852d-ad3205f79e3f.png)

ICEBOXER systemizes a hard decision - when is a valid issue not important enough to be fixed? 

To be productive, we must default to no.  Issues should be considered irrelevant until they've been brought up many times.  Open issue count in aggregate should not affect prioritization when the open issues themselves are of little impact.

So lets close some issues.

ICEBOXER:

ICEBOXER finds:
- issues older than a year, with no updates in last 2 months
- issues not touched in the last 6 months

To those issues, ICEBOXER:
- adds a comment
- tags the issue with the label 'Icebox'
- closes the issue

DEPRECATOR:

deprecator finds issues labelled 'deprecation' that have a date in the title somewhere.

Once the date has passed, it adds a comment telling the person to deal with the deprecation.
