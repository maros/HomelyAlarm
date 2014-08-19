package App::HomelyAlarm::Role::Database {
    
    use Moose::Role;
    requires qw(database_fields database_table);
    
    has 'database_id' => (
        is              => 'rw',
        isa             => 'Int',
        predicate       => 'is_in_database',
    );
    
    sub store {
        my ($self,$storage) = @_;
        
        my ($sql,@data);
        
        my $table = $self->database_table();
        my @fields = $self->database_fields();
        
        foreach my $field (@fields) {
            my $value = $self->$field;
            if (blessed $value
                && $value->can('database_id')) {
                $value = $value->database_id;
            }
            push(@data,$value);
        }
        
        if ($self->is_in_database) {
            $sql = 'UPDATE '.$table.' SET '.
                join(', ', map { $_.' = ?' } @fields).
                ' WHERE database_id = ?';
            push(@data,$self->database_id);
        } else {
            $sql = 'INSERT INTO '.$table.' ('.
                join(', ',@fields).
                ') VALUES ('.
                join(', ',( ('?') x scalar @fields)).
                ')';
        }
        
        $storage->dbh_do($sql,@data);
        
        unless ($self->is_in_database) {
            my $id = $storage->dbh->last_insert_id(undef, undef, $table, 'id');
            $self->database_id($id);
        }
    }
    
    sub remove {
        my ($self,$storage) = @_;
        my $table = $self->database_table();
        $storage->dbh_do('DELETE FROM '.$table.' WHERE id = ?',$self->database_id);
    }
    
    sub list {
        my ($class,$storage,$filter) = @_;
        
        my $sql = "SELECT 
            id,".join(",",$class->database_fields)."
            FROM ".$class->database_table;
        
        my ($sql_filtered,@sql_data) = $class->_filter($sql,$filter);
        my $sth = $storage->dbh->prepare($sql_filtered)
            or die($storage->dbh->errstr.':'.$sql_filtered);
        $sth->execute(@sql_data);
        
        my @result;
        while (my $row = $sth->fetchrow_hashref) {
            my $item = $class->_inflate($row);
            push(@result,$item)
                if defined $item;
        }
        
        return @result;
    }
    
    sub count {
        my ($class,$storage,$filter) = @_;
        
        my ($sql_filtered,@sql_data) = $class->_filter("SELECT COUNT(1) FROM ".$class->database_table,$filter);
        my $sth = $storage->dbh->prepare($sql_filtered);
        $sth->execute(@sql_data);
        my ($count) = $sth->fetchrow();
        $sth->finish();
        
        return $count;
    }
    
    sub _filter {
        my ($class,$sql,$filter) = @_;
        
        my (@where_sql,@where_data);
        if (defined $filter) {
            foreach my $field ($class->database_fields) {
                
#                if (blessed $filter 
#                    && $filter->does('App::HomelyAlarm::Role::Recipient')) {
#                    my $predicate = 'has_'.$field;
#                    if ($filter->can($predicate) 
#                        && $filter->$predicate) {
#                        push(@where_sql,$field.'=?');
#                        push(@where_data,$filter->$field);
#                    }
#                } els
                if (ref $filter eq 'HASH'
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
    
    sub _inflate {
        my ($class,$hashref) = @_;
        return
            unless defined $hashref;
        $hashref->{database_id} = delete $hashref->{id};
        foreach my $key (keys %{$hashref}) {
            delete $hashref->{$key} 
                unless defined $hashref->{$key};
        }
        return $class->new( %{$hashref});
    }
    
}

1;