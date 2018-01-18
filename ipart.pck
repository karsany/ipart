Create Or Replace Package ipart Authid Current_User Is

  /******************************************************************************
  * Copyright (c) 2017, Ferenc Karsany                                         *
  * All rights reserved.                                                       *
  *                                                                            *
  * Redistribution and use in source and binary forms, with or without         *
  * modification, are permitted provided that the following conditions are met:
  *                                                                            *
  *  * Redistributions of source code must retain the above copyright notice,  *
  *    this list of conditions and the following disclaimer.                   *
  *  * Redistributions in binary form must reproduce the above copyright       *
  *    notice, this list of conditions and the following disclaimer in the     *
  *    documentation and/or other materials provided with the distribution.    *
  *  * Neither the name of  nor the names of its contributors may be used to   *
  *    endorse or promote products derived from this software without specific *
  *    prior written permission.                                               *
  *                                                                            *
  * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE  *
  * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE *
  * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE   *
  * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR        *
  * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF       *
  * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS   *
  * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN    *
  * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)    *
  * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE *
  * POSSIBILITY OF SUCH DAMAGE.                                                *
  ******************************************************************************/

  Procedure exchange(p_tmp_table_name   In Varchar2,
                     p_partitioned_view In Varchar2,
                     p_tbl_part_name    In Varchar2);

  Procedure exchange(p_tmp_table_name In Varchar2,
                     p_date           In Date);

  Procedure dropp(p_partitioned_view In Varchar2,
                  p_tbl_part_name    In Varchar2);

  Procedure dropp(p_partitioned_view In Varchar2,
                  p_date             In Date);

End ipart;
/
Create Or Replace Package Body ipart Is

  Procedure exchange(p_tmp_table_name   In Varchar2,
                     p_partitioned_view In Varchar2,
                     p_tbl_part_name    In Varchar2) Is
  
    v_viewsql Clob;
  Begin
  
    -- rename tmp table
    Execute Immediate 'alter table ' || p_tmp_table_name || ' rename to ' || p_tbl_part_name;
  
    -- create new tmp table
    Execute Immediate 'create table ' || p_tmp_table_name || ' as select * from ' ||
                      p_tbl_part_name || ' where 1=2';
  
    -- refresh view
    v_viewsql := 'create or replace view ' || p_partitioned_view || ' as ' || chr(10);
  
    For r In (Select referenced_name
                From user_dependencies
               Where Name = upper(p_partitioned_view))
    Loop
    
      v_viewsql := v_viewsql || ' select * from ' || r.referenced_name || ' union all ' || chr(10);
    
    End Loop;
  
    v_viewsql := v_viewsql || ' select * from ' || p_tbl_part_name;
  
    Execute Immediate v_viewsql;
  
  End exchange;

  Procedure exchange(p_tmp_table_name In Varchar2,
                     p_date           In Date) Is
    v_view_name Varchar2(23);
  Begin
  
    v_view_name := substr(p_tmp_table_name, 1, length(p_tmp_table_name) - 4);
  
    exchange(p_tmp_table_name   => p_tmp_table_name,
             p_partitioned_view => v_view_name,
             p_tbl_part_name    => v_view_name || '_' || to_char(p_date, 'yymmdd'));
  
  End exchange;

  Procedure dropp(p_partitioned_view In Varchar2,
                  p_tbl_part_name    In Varchar2) Is
    v_viewsql  Clob;
    v_unionall Varchar2(100) := '';
  Begin
  
    -- refresh view
    v_viewsql := 'create or replace view ' || p_partitioned_view || ' as ' || chr(10);
  
    For r In (Select referenced_name
                From user_dependencies
               Where Name = upper(p_partitioned_view)
                 And referenced_name <> p_tbl_part_name)
    Loop
      v_viewsql  := v_viewsql || v_unionall || ' select * from ' || r.referenced_name;
      v_unionall := chr(10) || ' union all ';
    End Loop;
  
    Execute Immediate v_viewsql;
  
    -- drop table
    Execute Immediate 'drop table ' || p_tbl_part_name;
  
  End dropp;

  Procedure dropp(p_partitioned_view In Varchar2,
                  p_date             In Date) Is
  Begin
  
    dropp(p_partitioned_view, p_partitioned_view || '_' || to_char(p_date, 'yymmdd'));
  
  End dropp;

End ipart;
/
