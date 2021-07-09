
function evaluate_expression(patch, expr; verbose = 0)

    verbose > 0 && println("Parsing expression $expr")

    expr = replace(expr, "sqrt" => "√")
    ops = "+-*/^"
    methods = ["cos", "sin", "tan", "√", "abs", "atan"]
    """ 
    if there are any mathematical expressions inside the expression, 
    locate their indices 
    """
    idxs = Int[]
    if any(occursin.(methods, expr))
        where_methods = [findall(method, expr) for method in methods]
        if !isempty(where_methods)
            for ids in where_methods
                isempty(ids) && continue
                for id in ids
                    append!(idxs, id)
                end
            end
        end
    end

    # find the quantities in the expression that are being used 
    all_vars = patch["idx"]["dict"] |> keys |> collect
    for var in all_vars
        m = match(Regex("[$var]{$(length(var))}"), expr)
        if !isnothing(m) && !(m.offset in idxs)  
            expr = replace(expr, "$var" => """patch["var"]("$var")""")
        end
    end

    # vectorize the operations and mathemetical expressions
    for op in ops
        if occursin(op, expr)
            expr = replace(expr, op => " .$op ")
        end
    end
    for method in methods
        if occursin(method, expr)
            expr = replace(expr, method => " $method.")
        end
    end

    expr = replace(expr, "√" => "sqrt")

    # parse and evaluate
    verbose >= 1 && println("evaluating expression $expr")
    parsed = Meta.parse(expr)
    try
        # eval() looks for variables in global scope, so we have to force the
        # patch argument to be in its scope by using the `let` construct
        return @eval begin
            let patch = $patch 
                $parsed
            end
        end
    catch e
        throw(e)
    end

end
