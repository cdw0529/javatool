const
  srInvalidTableNameWarningFmt = 'Warning: Table name may be invalid - %s';
  srInvalidFieldNameWarningFmt = 'Warning: Field name may be invalid - %s';
  srDuplicateFieldNameWarningFmt = 'Warning: Duplicate field name - %s';
  DEF_VAL_auto_increment = '{auto_increment}';

  function GetQuotName(AName: string; dbType: string): string;
  begin
    Result := GetDbQuotName(AName,dbType);
  end;
  function ReplaceSingleQuotmark(val: string): string;
  begin
    Result := StringReplace(val, '''', '''''', [rfReplaceAll]);
  end;
  function ExtStr(Str: string; Len: Integer): string;
  var
    I: Integer;
    Span: string;
  begin
    Str := Trim(Str);
    Span := ' ';
    if Length(Str) <= Len then
      for I := Length(Str) to Len do
        Str := Str + Span;
    Result := Str;
  end;

  function GetSqlDbSchemaName: string;
  begin
    Result := 'dbo';
  end;
  function Get_FieldTypeStrEE(AField: TCtMetaField; dbType: string): string;
  begin
    Result := AField.GetFieldTypeDesc(True, dbType);
  end;
  function GetIndexPrefixInfo(AField: TCtMetaField; dbType: string): string;
  begin
    Result := '';
    if dbType = 'MYSQL' then
      if AField.DataType = cfdtString then
        if AField.DataLength > 255 then
           Result := '(255)';
  end;

  function IsNameOk(AName: string): Boolean;
  var
    I, C: Integer;
  begin
    Result := True;
    if IsReservedKeyworkd(AName) then
      Result := False
    else
      for I := 1 to Length(AName) do
      begin
        C := Ord(AName[I]);
        if C < 128 then
        begin
          if C = 95 then //_
            Continue;
          if (C >= 48) and (C <= 57) then //0-9
            Continue;
          if (C >= 65) and (C <= 90) then //A-Z
            Continue;
          if (C >= 97) and (C <= 122) then //A-Z
            Continue;
          Result := False;
          Break;
        end;
      end;
  end;

  function GetFieldDefaultValDesc(AField: TCtMetaField; dbType: string): string;
  begin
    Result := AField.GetFieldDefaultValDesc(dbType);
  end;


  function EzGenSqlEx(ATb: TCtMetaTable; bCreatTb: Boolean; bFK: Boolean; dbType: string): string;
  var
    I, J, C: Integer;
    vTbn, S, T, sComment, sPK, sFK, sIdx, sFPN: string;
    Infos: TStringList;
    f: TCtMetaField;
    pkAdded: Boolean;
  begin
    Infos := TStringList.Create;
    try

      T := '';
      pkAdded := False;

      S := ATb.Name;
      if not IsNameOk(S) then
      begin
        if T <> '' then
          T := T + #13#10;
        T := T + Format(srInvalidTableNameWarningFmt, [S]);
      end;

      for I := 0 to ATb.MetaFields.Count - 1 do
        if ATb.MetaFields[I].DataLevel <> ctdlDeleted then
        begin
          S := ATb.MetaFields[I].Name;
          if not IsNameOk(S) then
          begin
            if T <> '' then
              T := T + #13#10;
            T := T + Format(srInvalidFieldNameWarningFmt, [S]);
          end;

          for J := I - 1 downto 0 do
            if ATb.MetaFields[J].DataLevel <> ctdlDeleted then
              if UpperCase(S) = UpperCase(ATb.MetaFields[J].Name) then
              begin
                if T <> '' then
                  T := T + #13#10;
                T := T + Format(srDuplicateFieldNameWarningFmt, [S]);
              end;
        end;

      if T <> '' then
      begin
        Infos.Add('/*');
        Infos.Add(T);
        Infos.Add('*/');
      end;

      vTbn := ATb.Name;
      if vTbn = '' then
        vTbn := ATb.Caption;

      vTbn := GetQuotName(vTbn, dbType);

      S := 'create table  ' + vTbn;
      if Dbtype='SQLITE' then
      begin
        S :=S+#13#10'/**EZDML_DESC_START**'#13#10+Trim(ATb.Describe)+#13#10'**EZDML_DESC_END**/';
      end;
      S := S + #13#10'(';
      if bCreatTb then
        Infos.Add(S);

      S := '';
      sComment := '';
      sPK := '';
      sFK := '';
      sIdx := '';
      C := 0;

      T := ATb.GetTableComments;
      if T <> '' then
      begin
        if (dbType = 'ORACLE') or (dbType = 'POSTGRESQL') then
        begin
          if sComment <> '' then
            sComment := sComment + #13#10;
          sComment := sComment + 'comment on table '
            + vTbn + ' is ''' + ReplaceSingleQuotmark(T) + ''';';
        end
        else if dbType = 'SQLSERVER' then
        begin
          if sComment <> '' then
            sComment := sComment + #13#10;
          sComment := sComment + 'EXEC sp_addextendedproperty ''MS_Description'', ''' +
            ReplaceSingleQuotmark(T) + ''', ''user'', ' + GetSqlDbSchemaName + ', ''table'', ' + vTbn + ', NULL, NULL;';
        end
        else if dbType = 'MYSQL' then
        begin
          if sComment <> '' then
            sComment := sComment + #13#10;
          sComment := sComment + 'alter table '
            + vTbn + ' comment= ''' + ReplaceSingleQuotmark(T) + ''';';
        end;
      end;

      for I := 0 to ATb.MetaFields.Count - 1 do
        if ATb.MetaFields[I].DataLevel <> ctdlDeleted then
        begin
          f := ATb.MetaFields[I];
          if F.DataLevel = ctdlDeleted then
            Continue;
          case F.DataType of
            cfdtList, cfdtFunction, cfdtEvent:
              Continue;
          end;
          C := C+1;
          if C > 1 then
            S := S + ','#13#10;
          sFPN := f.Name;
          {if sFPN = '' then
            sFPN := f.DisplayName; }
          sFPN := GetQuotName(sFPN, dbType);
          S := S + ExtStr(' ', 6) + ExtStr(sFPN, 16);
          T := Get_FieldTypeStrEE(F, dbType);
          S := S + ' ' + T;
          if F.DefaultValue <> '' then
          begin
            S := S + GetFieldDefaultValDesc(F, dbType);
          end;
          if not F.Nullable then
            S := S + ' not null';

          T := F.GetFieldComments;
          if T <> '' then
          begin
            if (dbType = 'ORACLE') or (dbType = 'POSTGRESQL') then
            begin
              if sComment <> '' then
                sComment := sComment + #13#10;
              sComment := sComment + 'comment on column '
                + vTbn + '.' + sFPN + ' is ''' + ReplaceSingleQuotmark(T) + ''';';
            end
            else if dbType = 'SQLSERVER' then
            begin
              if sComment <> '' then
                sComment := sComment + #13#10;
              sComment := sComment + 'EXEC sp_addextendedproperty ''MS_Description'', ''' +
                ReplaceSingleQuotmark(T) + ''', ''user'', ' + GetSqlDbSchemaName + ', ''table'', ' + vTbn + ', ''column'', ' + sFPN + ';';
            end
            else if dbType = 'MYSQL' then
              S := S + ' comment ''' + ReplaceSingleQuotmark(T) + '''';
          end;

          T := GetIdxName(ATb.Name, f.Name);
          if F.KeyFieldType = cfktId then
          begin
            if dbType='SQLITE' then
            begin
              //sqlite主键在字段中直接定义
            end
            else if (dbType='MYSQL') and (Trim(F.DefaultValue) = DEF_VAL_auto_increment) then
            begin
              //mysql自增型主键改在字段中直接定义
            end
            else if not pkAdded then
            begin
              pkAdded := True;
              if sPK <> '' then
                sPK := sPK + #13#10;
              sPK := sPK + 'alter  table ' + vTbn + #13#10 +
                '       add constraint ' + GetQuotName('PK_' + T, dbType) + ' primary key (' + ATb.KeyFieldName + ');';
            end;
          end
          else
          begin
            if (F.KeyFieldType = cfktRid) and (F.RelateTable <> '')
              and (F.RelateField <> '') then
            begin
              if dbType='SQLITE' then
              begin
                //sqlite外键在字段中直接定义
              end
              else
              begin
                if sFK <> '' then
                  sFK := sFK + #13#10;
                sFK := sFK + 'alter  table ' + vTbn + #13#10 +
                  '       add constraint ' + GetQuotName('FK_' + T, dbType) + ' foreign key (' + sFPN + ')' + #13#10 +
                  '       references ' + GetQuotName(F.RelateTable, dbType) + '(' + GetQuotName(F.RelateField, dbType) + ');';
              end;
            end;
            if F.IndexType = cfitUnique then
            begin
              if sIdx <> '' then
                sIdx := sIdx + #13#10;
              sIdx := sIdx + 'create unique index ' + GetQuotName('IDXU_' + T, dbType) + ' on ' + vTbn + '(' + sFPN + GetIndexPrefixInfo(F, dbType) + ');';
            end
            else if F.IndexType = cfitNormal then
            begin
              if sIdx <> '' then
                sIdx := sIdx + #13#10;
              sIdx := sIdx + 'create index ' + GetQuotName('IDX_' + T, dbType) + ' on ' + vTbn + '(' + sFPN + GetIndexPrefixInfo(F, dbType) + ');';
            end
            else if (F.KeyFieldType = cfktRid) then
            begin
              if sIdx <> '' then
                sIdx := sIdx + #13#10;
              sIdx := sIdx + 'create index ' + GetQuotName('IDX_' + T, dbType) + ' on ' + vTbn + '(' + sFPN + GetIndexPrefixInfo(F, dbType) + ');';
            end;
          end;
        end;

      if dbType = 'ORACLE' then
      begin
        if Copy(ATb.Name, 1, 3) = 'TT_' then
          S := S + #13#10')'#13#10'on commit delete rows;'
        else if Copy(ATb.Name, 1, 3) = 'TS_' then
          S := S + #13#10')'#13#10'on commit preserve rows;'
        else
          S := S + #13#10');';
      end
      else
        S := S + #13#10');';
      if bCreatTb then
        Infos.Add(S);

      if bCreatTb then
      begin
        if sPK <> '' then
          Infos.Add(sPK);
        if sFK <> '' then
          if bFK then
            Infos.Add(sFK);
        if sIdx <> '' then
          Infos.Add(sIdx);

        if sComment <> '' then
          Infos.Add(sComment);
        if dbType = 'ORACLE' then
          Infos.Add('create sequence SEQ_' + ATb.Name + ';');
        Infos.Add('');
      end
      else if bFK then
        Infos.Add(sFK);
      Result := infos.Text;
    finally
      infos.Free;
    end;
  end;

var
  I, C: Integer;
  V, S: string;
  f: TCtMetaField;
begin
  CurOut.Add('--test custom sql gen by huz oracle----');
  V:=EzGenSqlEx(CurTable, True, True, 'ORACLE');
  CurOut.Add(V);
  
  CurOut.Add('');
  CurOut.Add('--test custom sql gen by huz mysql----');
  V:=EzGenSqlEx(CurTable, True, True, 'MYSQL');
  CurOut.Add(V);
  
  CurOut.Add('');
  CurOut.Add('--test custom sql gen by huz mssql----');
  V:=EzGenSqlEx(CurTable, True, True, 'SQLSERVER');
  CurOut.Add(V);

  CurOut.Add('');
  CurOut.Add('--test custom sql gen by huz sqlite----');
  V:=EzGenSqlEx(CurTable, True, True, 'SQLITE');
  CurOut.Add(V);

  with CurTable do
  begin
    CurOut.Add('');
    CurOut.Add('update ' + Name);
    CurOut.Add('set');
    S := '';
    C := 0;
    for I := 0 to MetaFields.Count - 1 do
      if MetaFields[I].DataLevel <> ctdlDeleted then
      begin
        f := MetaFields[I];
        if F.DataLevel = ctdlDeleted then
          Continue;
        case F.DataType of
          cfdtList, cfdtFunction, cfdtEvent:
            Continue;
        end;
        C:=C+1;
        if C > 1 then
          S := S + ','#13#10;
        if 'MYSQL2' = 'MYSQL' then
          S := S + '  ' + ExtStr('`' + f.Name + '`', 16)
        else
          S := S + '  ' + ExtStr(f.Name, 16);
        S := S + ' = :' + f.Name;
      end;
    CurOut.Add(S);
    S := KeyFieldName;
    if S = '' then
      S := 'id';
    CurOut.Add('where ' + S + ' = :' + S + ';');
  end;
end.
