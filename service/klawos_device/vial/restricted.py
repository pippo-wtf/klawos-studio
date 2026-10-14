"""Bounded integer-only QMK expression evaluator. No eval/exec or attribute access."""
import ast, operator
DEFAULT_OPERATORS = {ast.Add:operator.add,ast.Sub:operator.sub,ast.Mult:operator.mul,
    ast.FloorDiv:operator.floordiv,ast.Mod:operator.mod,ast.LShift:operator.lshift,
    ast.RShift:operator.rshift,ast.BitOr:operator.or_,ast.BitAnd:operator.and_,ast.BitXor:operator.xor}
def simple_eval(source, *, names, functions, operators):
    if not isinstance(source,str) or len(source)>512: raise ValueError('Keycode expression too long')
    try: root=ast.parse(source,mode='eval')
    except (SyntaxError,RecursionError) as e: raise ValueError('Invalid keycode expression') from e
    if sum(1 for _ in ast.walk(root))>64: raise ValueError('Keycode expression too complex')
    def integer(value):
        if type(value) is not int or abs(value)>0xffffffff: raise ValueError('Invalid integer expression')
        return value
    def visit(node):
        if isinstance(node,ast.Constant): return integer(node.value)
        if isinstance(node,ast.Name) and node.id in names: return integer(names[node.id])
        if isinstance(node,ast.UnaryOp) and isinstance(node.op,(ast.UAdd,ast.USub,ast.Invert)):
            value=visit(node.operand)
            return integer(value if isinstance(node.op,ast.UAdd) else -value if isinstance(node.op,ast.USub) else ~value)
        if isinstance(node,ast.BinOp) and type(node.op) in operators:
            left,right=visit(node.left),visit(node.right)
            if isinstance(node.op,(ast.LShift,ast.RShift)) and not 0<=right<=16: raise ValueError('Shift out of bounds')
            return integer(operators[type(node.op)](left,right))
        if isinstance(node,ast.Call) and isinstance(node.func,ast.Name) and node.func.id in functions and not node.keywords and len(node.args)<=2:
            return integer(functions[node.func.id](*(visit(arg) for arg in node.args)))
        raise ValueError('Unsupported keycode expression')
    return visit(root.body)
