-module(tq_sqlmodel_runtime).

-export([save/1]).

save(Model) ->
    Changed = Model:get_changed_fields(),
    case {Model:is_new(), Changed} of
        {true, []} ->
			{error,not_changed};
		{false, []} ->
			ok;
		{IsNew, _} ->
			Table = Model:'$meta'(table),
			Returning = Model:'$meta'({sql,{db_fields,r}}),
			Constructor = (element(1, Model)):constructor(Model:'$meta'({db_fields,r})),
			Args = [{Model:'$meta'({db_type,F}),V} || {F,V} <- Changed],
			case IsNew of
				true ->
					Fields = join([Model:'$meta'({db_alias,F}) || {F,_} <- Changed], $,),
					Values = join(["~s" || _ <- Changed], $,),
					Sql = ["INSERT INTO ", Table, "(", Fields, ") VALUES (", Values, ") RETURNING ", Returning, ";"],
					tq_sql:'query'(db, Sql, Args, Constructor);
				false ->
					Indexes = Model:'$meta'(indexes),
					Values = join([[Model:'$meta'({db_alias, F}), " = ~s"] || {F, _} <- Changed], $,),
					Where1 = join([[Model:'$meta'({db_alias, F}), " = ~s"] || F <- Indexes], " AND "),
					Where2 = case Where1 of
								 [] -> [];
								 _ -> [" WHERE ", Where1]
							 end,
					WhereArgs = [{Model:'$meta'({db_type, F}), Model:F()} || F <- Indexes],
					Sql = ["UPDATE ", Table, " SET ", Values, Where2, " RETURNING ", Returning, ";"],
					tq_sql:'query'(db, Sql, Args ++ WhereArgs, Constructor)
			end
	end.


join([], _Sep) ->
	[];
join([H|T], Sep) ->
	[H | [[Sep, E] || E <- T]].
