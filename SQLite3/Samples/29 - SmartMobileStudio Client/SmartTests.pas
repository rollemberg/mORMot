unit SmartTests;

interface

uses 
  SmartCL.System,
  System.Types,
  w3c.date,
  SynCrossPlatformSpecific,
  SynCrossPlatformREST,
  SynCrossPlatformCrypto;

procedure TestSMS;

procedure ORMTest(client: TSQLRestClientHTTP);

type
  TSQLRecordPeople = class(TSQLRecord)
  protected
    fData: TSQLRawBlob;
    fFirstName: RawUTF8;
    fLastName: RawUTF8;
    fYearOfBirth: integer;
    fYearOfDeath: word;
    // those RTTI-related overriden methods will be generated by the server
    class function ComputeRTTI: TRTTIPropInfos; override;
    procedure SetProperty(FieldIndex: integer; const Value: variant); override;
    function GetProperty(FieldIndex: integer): variant; override;
published
    property FirstName: RawUTF8 read fFirstName write fFirstName;
    property LastName: RawUTF8 read fLastName write fLastName;
    property Data: TSQLRawBlob read fData write fData;
    property YearOfBirth: integer read fYearOfBirth write fYearOfBirth;
    property YearOfDeath: word read fYearOfDeath write fYearOfDeath;
  end;

implementation

const
  MSecsPerDay = 86400000;
  OneSecDateTime = 1000/MSecsPerDay;

procedure TestsIso8601DateTime;
  procedure Test(D: TDateTime);
  var s: string;
  procedure One(D: TDateTime);
  var E: TDateTime;
      V: TTimeLog;
      J: JDate;
  begin
    J := new JDate;
    J.AsDateTime := D;
    E := J.AsDateTime;
    assert(Abs(D-E)<OneSecDateTime);
    s := DateTimeToIso8601(D);
    E := Iso8601ToDateTime(s);
    assert(Abs(D-E)<OneSecDateTime);
    V := DateTimeToTTimeLog(D);
    E := TTimeLogToDateTime(V);
    assert(Abs(D-E)<OneSecDateTime);
    assert(UrlDecode(UrlEncode(s))=s);
  end;
  begin
    One(D);
    assert(length(s)=19);
    One(Trunc(D));
    assert(length(s)=10);
    One(Frac(D));
    assert(length(s)=9);
  end;
var D: TDateTime;
    i: integer;
    s,x: string;
    T: TTimeLog;
begin
  s := '2014-06-28T11:50:22';
  D := Iso8601ToDateTime(s);
  assert(Abs(D-41818.49331)<OneSecDateTime);
  assert(DateTimeToIso8601(D)=s);
  x := TTimeLogToIso8601(135181810838);
  assert(x=s);
  T := DateTimeToTTimeLog(D);
  assert(T=135181810838);
  D := Now/20+Random*20; // some starting random date/time
  for i := 1 to 2000 do begin
    Test(D);
    D := D+Random*57; // go further a little bit: change date/time
  end;
end;

procedure TestSMS;
var doc: TJSONVariantData;
begin
  assert(crc32ascii(0,'abcdefghijklmnop')=$943AC093);
  assert(SHA256('abc')='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  assert(VariantType(123)=jvUndefined);
  assert(VariantType(null)=jvUndefined);
  assert(VariantType(TVariant.CreateObject)=jvObject);
  assert(VariantType(TVariant.CreateArray)=jvArray);
  doc := TJSONVariantData.Create('{"a":1,"b":"B"}');
  assert(doc.Kind=jvObject);
  assert(doc.Count=2);
  assert(doc.Names[0]='a');
  assert(doc.Names[1]='b');
  assert(doc.Values[0]=1);
  assert(doc.Values[1]='B');
  doc := TJSONVariantData.Create('["a",2]');
  assert(doc.Kind=jvArray);
  assert(doc.Count=2);
  assert(doc.Names.Count=0);
  assert(doc.Values[0]='a');
  assert(doc.Values[1]=2);
  TestsIso8601DateTime;
end;


{ TSQLRecordPeople }

class function TSQLRecordPeople.ComputeRTTI: TRTTIPropInfos;
begin
  result := TRTTIPropInfos.Create(
    ['Data','FirstName','LastName','YearOfBirth','YearOfDeath'],
    [sftBlob]);
end;

function TSQLRecordPeople.GetProperty(FieldIndex: Integer): Variant;
begin
  case FieldIndex of
  0: result := fID;
  1: result := fData;
  2: result := fFirstName;
  3: result := fLastName;
  4: result := fYearOfBirth;
  5: result := fYearOfDeath;
  end;
end;

procedure TSQLRecordPeople.SetProperty(FieldIndex: Integer; const Value: Variant);
begin
  case FieldIndex of
  0:  fID := Value;
  1:  fData := Value;
  2:  fFirstName := Value;
  3:  fLastName := Value;
  4:  fYearOfBirth := Value;
  5:  fYearOfDeath := Value;
  end;
end;


procedure ORMTest(client: TSQLRestClientHTTP);
var people: TSQLRecordPeople;
    Call: TSQLRestURIParams;
    res: TIntegerDynArray;
    i,id: integer;
begin // all this is run in synchronous mode -> only 200 records in the set
  client.CallBackGet('DropTable',[],Call,TSQLRecordPeople);
  assert(Call.OutStatus=HTML_SUCCESS);
  client.BatchStart(TSQLRecordPeople);
  people := TSQLRecordPeople.Create;
  for i := 1 to 200 do begin
    people.FirstName := 'First'+IntToStr(i);
    people.LastName := 'Last'+IntToStr(i);
    people.YearOfBirth := i+1800;
    people.YearOfDeath := i+1825;
    assert(client.BatchAdd(people,true)=i-1);
  end;
  assert(client.BatchSend(res)=HTML_SUCCESS);
  assert(length(res)=200);
  for i := 1 to 200 do
    assert(res[i-1]=i);
  people := TSQLRecordPeople.CreateAndFillPrepare(client,'','',[]);
  id := 0;
  while people.FillOne do begin
    inc(id);
    assert(people.ID=id);
    assert(people.FirstName='First'+IntToStr(id));
    assert(people.LastName='Last'+IntToStr(id));
    assert(people.YearOfBirth=id+1800);
    assert(people.YearOfDeath=id+1825);
  end;
  assert(id=200);
  people.Free; // release all memory used by the request
  people := TSQLRecordPeople.CreateAndFillPrepare(client,
    'YearOFBIRTH,Yearofdeath,id','',[]);
  id := 0;
  while people.FillOne do begin
    inc(id);
    assert(people.ID=id);
    assert(people.FirstName='');
    assert(people.LastName='');
    assert(people.YearOfBirth=id+1800);
    assert(people.YearOfDeath=id+1825);
  end;
  assert(id=200);
  people.Free; // release all memory used by the request
  people := TSQLRecordPeople.CreateAndFillPrepare(client,'',
    'yearofbirth=?',[1900]);
  id := 0;
  while people.FillOne do begin
    inc(id);
    assert(people.ID=100);
    assert(people.FirstName='First100');
    assert(people.LastName='Last100');
    assert(people.YearOfBirth=1900);
    assert(people.YearOfDeath=1925);
  end;
  assert(id=1);
  for i := 1 to 200 do
    if i and 15=0 then
      client.Delete(TSQLRecordPeople,i) else
    if i mod 82=0 then begin
      people := TSQLRecordPeople.Create;
      id := i+1;
      people.ID := i;
      people.FirstName := 'neversent';
      people.LastName := 'neitherthisone';
      people.YearOfBirth := id+1800;
      people.YearOfDeath := id+1825;
      assert(client.Update(people,'YEarOFBIRTH,YEarOfDeath'));
    end;
  people := new TSQLRecordPeople;
  for i := 1 to 200 do begin
    var read = client.Retrieve(i,people);
    if i and 15=0 then
      assert(not read) else begin
      assert(read);
      if i mod 82=0 then
        id := i+1 else
        id := i;
      assert(people.ID=i);
      assert(people.FirstName='First'+IntToStr(i));
      assert(people.LastName='Last'+IntToStr(i));
      assert(people.YearOfBirth=id+1800);
      assert(people.YearOfDeath=id+1825);
    end;
  end;
  people.Free;
end;

end.
