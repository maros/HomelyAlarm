package App::HomelyAlarm::Storage {
    use 5.014; 

    use Moose;
    
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
     
    sub _build_current_version {
        my ($self) = @_;
         
        my ($current_version) = $self->dbh->selectrow_array('SELECT value FROM meta WHERE key = ?',{},'database_version');
        $current_version ||= $Homely::Alarm::VERSION;
        return $current_version;
    }
    
    sub _build_dbh {
        my ($self) = @_;
         
        my $dbh;
        my $database_ok = 1;
        my $latest_version = $Homely::Alarm::VERSION;
        my $file = Path::Class::File->new($self->recipients_database);
         
        # Touch database file if it does not exist
        unless (-e $file->stringify) {
            $database_ok = 0;
            $file->touch
                or die('Could not create storage file %s: %s',$file->stringify,$!);
        }
         
        # Connect database
        {
            no warnings 'once';
            $dbh = DBI->connect("dbi:SQLite:dbname=$file","","",{ sqlite_unicode => 1 })
                or die('Could not connect to database: %s',$DBI::errstr);
        }
         
        # Set dbh
        $self->meta->get_attribute('dbh')->set_raw_value($self,$dbh);
         
        # Check database for meta table
        if ($database_ok) {
            ($database_ok) = $dbh->selectrow_array('SELECT COUNT(1) FROM sqlite_master WHERE type=? AND name = ?',{},'table','meta');
        }
         
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
            # TODO upgrade
        }
        
        $self->current_version($latest_version);
        $dbh->do('INSERT OR REPLACE INTO meta (key,value) VALUES (?,?)',{},'database_version',$latest_version);
         
        return $dbh;
    }
    
    __PACKAGE__->meta->make_immutable;
}

1;

__DATA__
CREATE TABLE IF NOT EXISTS recipient (
  id INTEGER NOT NULL PRIMARY KEY,
  email TEXT,
  telephone TEXT,
  only_vaccation INTEGER,
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