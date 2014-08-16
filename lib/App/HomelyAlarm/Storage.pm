package App::HomelyAlarm::Storage;
use 5.014; 

use Moose;

use DBI;

has 'dbh' => (
    is          => 'rw',
    lazy_build  => 1,
);

has 'database' => (
    required    => 1,
    is          => 'ro',
);

has 'current_version' => (
    is              => 'rw',
    isa             => 'Num',
    lazy_build      => 1,
    required        => 1,
);

our @FIELDS = qw(email telephone only_vacation only_call severity);
our $INSTANCE;

sub instance {
    my ($class,$database) = @_;
    
    return $INSTANCE
        if defined $INSTANCE;
    
    die("Database missing")
        unless defined $database;
    
    $INSTANCE = $class->new( database => $database );
    return $INSTANCE;
}

sub _build_current_version {
    my ($self) = @_;
     
    my ($current_version) = $self->dbh->selectrow_array('SELECT value FROM meta WHERE key = ?',{},'database_version');
    $current_version ||= $App::HomelyAlarm::VERSION;
    return $current_version;
}

sub _build_dbh {
    my ($self) = @_;
     
    my $dbh;
    my $latest_version = $App::HomelyAlarm::VERSION;
    my $file = Path::Class::File->new($self->database);
    
    # Connect database
    {
        no warnings 'once';
        $dbh = DBI->connect("dbi:SQLite:dbname=$file","","",{ sqlite_unicode => 1 })
            or die('Could not connect to database: %s',$DBI::errstr);
    }
     
    # Set dbh
    $self->meta->get_attribute('dbh')->set_raw_value($self,$dbh);
     
    # Check database for meta table
    my ($database_ok) = $dbh->selectrow_array('SELECT COUNT(1) FROM sqlite_master WHERE type=? AND name = ?',{},'table','meta');
    
    my $data_fh = *DATA;
    # Initialize database
    unless ($database_ok) {
        my $sql = '';
        while (my $line = <$data_fh>) {
            $sql .= $line;
            if ($sql =~ m/;/) {
                $dbh->do($sql)
                    or die('Could not excecute sql %s: %s',$sql,$dbh->errstr);
                undef $sql;
            }
        }
        close DATA;
    }
    
    # Upgrade existing database
    if ($self->current_version < $latest_version)  {
        $database_ok = 0;
        # TODO upgrade
    }
    
    $self->current_version($latest_version);
    unless ($database_ok) {
        $dbh->do('INSERT OR REPLACE INTO meta (key,value) VALUES (?,?)',{},'database_version',$latest_version);
    }
     
    return $dbh;
}

sub _filter {
    my ($self,$sql,$filter) = @_;
    
    my (@where_sql,@where_data);
    if (defined $filter) {
        foreach my $field (@FIELDS) {
            
            if (blessed $filter 
                && $filter->does('App::HomelyAlarm::Role::Recipient')) {
                my $predicate = 'has_'.$field;
                if ($filter->can($predicate) 
                    && $filter->$predicate) {
                    push(@where_sql,$field.'=?');
                    push(@where_data,$filter->$field);
                }
            } elsif (ref $filter eq 'HASH'
                && defined $filter->{$field}) {
                push(@where_sql,$field.'=?');
                push(@where_data,$filter->{$field});
            }
        }
        if (scalar @where_data) {
            $sql .= ' WHERE '.join(' AND ',@where_sql);
        }
    }
    
    return ($sql,@where_data);
}

sub recipients_list {
    my ($self,$filter) = @_;
    
    my $sql = "SELECT 
        id,".join(",",@FIELDS)."
        FROM recipient";
    
    my ($sql_filtered,@sql_data) = $self->_filter($sql,$filter);
    my $sth = $self->dbh->prepare($sql_filtered);
    $sth->execute(@sql_data);
    
    my @recipients;
    while (my $row = $sth->fetchrow_arrayref) {
        my $i = 1;
        my %params = (
            database_id => $row->[0],
        );
        my $index = 0;
        foreach my $field (@FIELDS) {
            $index++;
            next
                unless defined $row->[$index];
            $params{$field} = $row->[$index];
        }
        push(@recipients,App::HomelyAlarm::Recipient->new(%params));
    }
    
    $sth->finish();
    
    return @recipients;
}

sub recipients_count {
    my ($self,$filter) = @_;
    
    my ($sql_filtered,@sql_data) = $self->_filter("SELECT COUNT(1) FROM recipient",$filter);
    my $sth = $self->dbh->prepare($sql_filtered);
    $sth->execute(@sql_data);
    my ($count) = $sth->fetchrow();
    $sth->finish();
    
    return $count;
}

sub remove_recipient {
    my ($self,$recipient) = @_;
    
    $self->dbh->do('DELETE FROM message WHERE recipient = ?',{},$recipient->database_id);
    $self->dbh->do('DELETE FROM recipient WHERE id = ?',{},$recipient->database_id);
}

sub store_recipient {
    my ($self,$recipient) = @_;
    
    my ($sql,@data);
    
    foreach my $field (@FIELDS) {
        push(@data,$recipient->$field);
    }
    
    if ($recipient->is_in_database) {
        $sql = 'UPDATE recipient SET '.
            join(', ', map { $_.' = ?' } @FIELDS).
            ' database_id = ?';
        push(@data,$recipient->database_id);
    } else {
        $sql = 'INSERT INTO recipient ('.
            join(', ',@FIELDS).
            ') VALUES ('.
            join(', ',( ('?') x scalar @FIELDS)).
            ')';
    }
    
    $self->dbh->do($sql,{},@data);
    
}

__PACKAGE__->meta->make_immutable;

1;

__DATA__
CREATE TABLE IF NOT EXISTS recipient (
  id INTEGER NOT NULL PRIMARY KEY,
  email TEXT,
  telephone TEXT,
  only_vacation INTEGER,
  only_call INTEGER,
  severity TEXT
);

CREATE TABLE IF NOT EXISTS message (
  id INTEGER NOT NULL PRIMARY KEY,
  recipient INTEGER NOT NULL,
  timestamp INTEGER NOT NULL,
  mode TEXT NOT NULL,
  message TEST NOT NULL,
  reference TEXT
);

CREATE INDEX IF NOT EXISTS message_recipient_index ON message(recipient);

CREATE TABLE IF NOT EXISTS meta (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);