package ActivityStream::REST::Constants;

use strict;
use warnings;

use Readonly;

# > RID
Readonly our $ERROR_MESSAGE_NO_RID_DEFINED => 'NO_RID_DEFINED';
Readonly our $ERROR_MESSAGE_BAD_RID        => 'BAD_RID';

# > ACTIVITY
Readonly our $ERROR_MESSAGE_ACTIVITY_NOT_FOUND => 'ACTIVITY_NOT_FOUND';

# > ACTIVITY > LIKE
Readonly our $ERROR_MESSAGE_LIKE_NOT_FOUND => 'LIKE_NOT_FOUND';

1;
