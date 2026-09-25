"""Logical foreign keys of the ASCON schema that are not declared as constraints (column name -> parent table, parent column).
Used for lists of values on screens and for names on printed documents. Verified 2026-09-22: ST_ITEM.ITEM_CODE is unique
(4,035 rows / 4,035 distinct), CUSTOMER / SUPPLIER / SALESMAN keyed by CODE."""
LOGICAL_FKS = {
    "ITEM_CODE": ("ST_ITEM", "ITEM_CODE"),
    "CUSTOMER_CODE": ("CUSTOMER", "CODE"), "CUSTOMER_ID": ("CUSTOMER", "CODE"), "CUST_CODE": ("CUSTOMER", "CODE"),
    "SUPPLIER_CODE": ("SUPPLIER", "CODE"), "SUPPLIER_ID": ("SUPPLIER", "CODE"), "SUPP_CODE": ("SUPPLIER", "CODE"),
    "SALESMAN_CODE": ("SALESMAN", "CODE"),
    "COST_CODE": ("AC_COST_CENTERS", "COST_CODE"), "COST_CODE2": ("AC_COST_CENTERS2", "COST_CODE"),
    "UNIT_CODE": ("ST_UNIT", "UNIT_CODE"),
    "CURRENCY_CODE": ("AC_CURRENCY", "CURRENCY_CODE"),
    "ACCOUNT_NUMBER": ("AC_MASTER", "ACCOUNT_NUMBER"),
    "STORE_CODE": ("ST_STORE", "STORE_CODE"), "FROM_STORE_CODE": ("ST_STORE", "STORE_CODE"), "TO_STORE_CODE": ("ST_STORE", "STORE_CODE"),
    "GROUP_CODE": ("ST_ITEM_GROUP", "ITEM_GROUP_CODE"), "ITEM_GROUP_CODE": ("ST_ITEM_GROUP", "ITEM_GROUP_CODE"),
}


def logical_parent(table, col, meta):
    """(parent, pcol) when table.col refers logically to a code table (not the code table's own key)."""
    p = LOGICAL_FKS.get(col)
    if not p or p[0] == table or p[0] not in meta:
        return None
    return p
