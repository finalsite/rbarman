require 'spec_helper'

include RBarman

describe Backup do

  before :each do
    @backup = Backup.new
  end

  describe "#new" do
    it 'should be an instance of a Backup object' do
      @backup.should be_an_instance_of Backup
    end

    it 'deleted should be false' do
      expect(@backup.deleted).to eq(false)
    end
  end

  describe "server=" do
    it 'should assign a name' do
      @backup.server = '123'
      expect(@backup.server).to eq('123')
    end
  end

  describe ".backup_id_valid?" do
    it 'should return false when argument is nil' do
      expect(Backup.backup_id_valid?(nil)).to eq(false)
    end

    it 'should return false when argument is empty' do
      expect(Backup.backup_id_valid?("")).to eq(false)
    end

    it 'should return true when argument like "20130304T080002"' do
      Backup.backup_id_valid?("20130304T080002").should == true
    end
  end

  describe "id=" do
    it 'should raise InvalidBackupIdError if id is invalid' do
      lambda { @backup.id = '123' }.should raise_error(InvalidBackupIdError)
    end
  end

  describe "backup_start=" do
    it 'should allow valid time strings' do
      t = Time.now.to_s
      @backup.backup_start = t
      @backup.backup_start.to_s == t
    end
  end

  describe "backup_end=" do
    it 'should allow valid time strings' do
      t = Time.now.to_s
      @backup.backup_end = t
      @backup.backup_end.to_s == t
    end
  end

  describe "status=" do
    it 'should raise ArgumentError if arg not like :empty, :started, :done or :failed' do
      lambda { @backup.status = 'started' }.should raise_error(ArgumentError)
      lambda { @backup.status = :some }.should raise_error(ArgumentError)
    end

    it 'should accept args like :empty, :started, :done or :failed' do
      states = [ :started, :empty, :done, :failed ]
      states.each do |state|
        @backup.status = state
        @backup.status.should == state
      end
    end
  end

  describe "wal_files=" do
    it 'should raise ArgumentError if arg not an array' do
      lambda { @backup.wal_files = nil }.should raise_error(ArgumentError)
      lambda { @backup.wal_files = 1 }.should raise_error(ArgumentError)
    end

    it 'should accept args of type Array' do
      a = [ "1", "2", "3" ]
      @backup.wal_files = a
      @backup.wal_files.should == a
    end
  end

  describe "size=" do
    it 'should assign a size' do
      a = 123
      @backup.size = a
      @backup.size.should == a
    end
  end

  describe "wal_file_size=" do
    it 'should assign a wal file size' do
      a = 123
      @backup.wal_file_size = a
      @backup.wal_file_size.should == a
    end
  end

  describe "begin_wal=" do
    it 'should accept args of type WalFile' do
      w = WalFile.parse("0000000100000599000000D5")
      @backup.begin_wal = w
      expect(@backup.begin_wal).to eq(w)
    end
  end

  describe "end_wal=" do
    it 'should accept args of type WalFile' do
      w = WalFile.parse("0000000100000599000000D5")
      @backup.end_wal = w
      expect(@backup.end_wal).to eq(w)
    end
  end

  describe "timeline=" do
    it 'should raise ArgumentError if arg is 0' do
      expect { @backup.timeline = 0 }.to raise_error(ArgumentError)
    end

    it 'should accept args of type integer' do
      @backup.timeline = 1
      expect(@backup.timeline).to eq(1)
    end
  end

  describe "pgdata=" do
    it 'should raise ArgumentError if arg is empty' do
      expect { @backup.pgdata = '' }.to raise_error(ArgumentError)
    end

    it 'should accecpt string args' do
      @backup.pgdata = "/path/to/pgdata"
      expect(@backup.pgdata).to eq('/path/to/pgdata')
    end

  end

  describe "wal_file_already_added?" do
    it 'should return true if a duplicate exists' do
      @backup.add_wal_file(WalFile.parse("000000010000049A000000DA"))
      @backup.wal_file_already_added?(WalFile.parse("000000010000049A000000DA")).should == true
    end

    it 'should return false if no duplicate exists' do
      @backup.add_wal_file(WalFile.parse("000000010000049A000000DA"))
      @backup.wal_file_already_added?(WalFile.parse("000000010000049A000000CE")).should == false
    end
  end

  describe "add_wal_file" do
    it 'should accept args of type WalFile' do
      files = ["000000010000049A000000DA", "000000010000049F000000CE"]
      files.each do |file|
        @backup.add_wal_file(WalFile.parse(file))
      end
      @backup.wal_files.count.should == 2
    end
  end

  describe "xlog_range" do
    it 'should return the range of xlog entries' do
      @backup.begin_wal = WalFile.parse("0000000100000CB6000000EC")
      @backup.add_wal_file(WalFile.parse("0000000100000CB700000010"))
      xlog_range = @backup.xlog_range
      expect(xlog_range.count).to eq(2)
      expect(xlog_range[0]).to eq("CB6")
      expect(xlog_range[1]).to eq("CB7")
    end
  end

  describe "needed_wal_files" do
    it 'should return an array of wal files which should be available in a backup' do
      @backup.begin_wal = WalFile.parse("0000000100000CB6000000EC")
      @backup.add_wal_file(WalFile.parse("0000000100000CB700000010"))
      needed = @backup.needed_wal_files
      expect(needed.count).to eq 36
      expect(needed.first.segment).to eq("000000EC")
      expect(needed.select { |n| n.segment == '000000EF' }.count).to eq 1
      expect(needed.last.segment).to eq("00000010")
    end

    it 'should not include segment xxxxxxFF if PG version < 9.3' do
      @backup.begin_wal = WalFile.parse("0000000100000CB6000000E0")
      @backup.add_wal_file(WalFile.parse("0000000100000CB6000000FE"))
      @backup.pg_version = 90204
      needed = @backup.needed_wal_files
      expect(needed.count).to eq 31
      expect(needed.select { |n| n.segment == '000000EF' }.count).to eq 1
      expect(needed.select { |n| n.segment == '000000FF' }.count).to eq 0
    end

    it 'should include segment xxxxxxFF if PG version >= 9.3' do
      @backup.begin_wal = WalFile.parse("0000000100000CB6000000E0")
      @backup.add_wal_file(WalFile.parse("0000000100000CB6000000FF"))
      @backup.pg_version = 90300
      needed = @backup.needed_wal_files
      expect(needed.count).to eq 32
      expect(needed.select { |n| n.segment == '000000EF' }.count).to eq 1
      expect(needed.select { |n| n.segment == '000000FF' }.count).to eq 1
    end
  end

  describe "missing_wal_files" do
    it 'should return all missing wal files' do
      @backup.begin_wal = WalFile.parse("0000000100000CB6000000EC")
      [ "0000000100000CB6000000EC",
        "0000000100000CB6000000ED",
        "0000000100000CB6000000EE",
        "0000000100000CB6000000EF",
        "0000000100000CB6000000F0",
        "0000000100000CB6000000F1",
        "0000000100000CB6000000F2",
        "0000000100000CB6000000F3",
        "0000000100000CB6000000F5",
        "0000000100000CB6000000F6",
        "0000000100000CB6000000F7",
        "0000000100000CB6000000F8",
        "0000000100000CB6000000F9",
        "0000000100000CB6000000FA",
        "0000000100000CB6000000FB",
        "0000000100000CB6000000FC",
        "0000000100000CB6000000FD",
        "0000000100000CB6000000FE",
        "0000000100000CB700000000",
        "0000000100000CB700000001",
        "0000000100000CB700000002",
        "0000000100000CB700000003",
        "0000000100000CB700000004",
        "0000000100000CB700000006",
        "0000000100000CB700000007",
        "0000000100000CB700000008",
        "0000000100000CB700000009",
        "0000000100000CB70000000A",
        "0000000100000CB70000000B",
        "0000000100000CB70000000C",
        "0000000100000CB70000000D",
        "0000000100000CB70000000E",
        "0000000100000CB70000000F",
        "0000000100000CB700000010"
      ].each { |f| @backup.add_wal_file(f) }
      #  #"0000000100000CB6000000F4",
      #  #"0000000100000CB700000005",
      missing_wals = @backup.missing_wal_files
      expect(missing_wals.count).to eq(2)
    end
  end

  describe "delete" do
    it 'should set deleted to true' do
      @backup.server = "test"
      @backup.id = "20130304T080002"
      File.stub!(:exists?).and_return(true)
      CliCommand.any_instance.stub(:delete)
      CliCommand.any_instance.should_receive(:delete).once.with(@backup.server, @backup.id)
      @backup.delete
      expect(@backup.deleted).to eq(true)
    end
  end

  describe "create" do
    it 'should create a backup and return the latest backup' do
      File.stub!(:exists?).and_return(true, true)
      CliCommand.any_instance.stub(:create)
      backups = Backups.new
      backups << Backup.new.tap { |b| b.id = "20130304T080002" }
      backups << Backup.new.tap { |b| b.id = "20130303T081002" }
      backups << Backup.new.tap { |b| b.id = "20130305T130002" }
      CliCommand.any_instance.stub(:backups).and_return(backups)
      CliCommand.any_instance.stub(:backup).and_return(backups[2])
      expect(Backup.create('test').id).to eq("20130305T130002")
    end
  end

  describe ".recover" do
    it 'should call barman with correct arguments' do
      @backup.server = 'test'
      @backup.id = "20130304T080002"
      CliCommand.any_instance.stub(:binary=)
      CliCommand.any_instance.stub(:recover)
      CliCommand.any_instance.should_receive(:recover).once.with(
        @backup.server, @backup.id, '/var/lib/postgresql/9.2/main', {:test => 123 })
      @backup.recover('/var/lib/postgresql/9.2/main', {:test => 123})
    end
  end
end
