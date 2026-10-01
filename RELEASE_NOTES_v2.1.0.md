# SmartStock v2.1.0 Patch Notes

SmartStock v2.1.0 is a major UI and reporting overhaul focused on improving usability, readability, and inventory tracking.

## UI / UX

- Refreshed the SmartStock user interface
- Improved overall navigation and layout
- Improved inventory item interaction
- Polished buttons, cards, dialogs, and general screen presentation
- Improved consistency across SmartStock screens

## Inventory

- Improved inventory management workflow
- Improved restock and dispense interactions
- Improved item information presentation
- Preserved existing inventory, audit, reporting, and database functionality

## Reports and Exports

- Added XLSX spreadsheet export support
- Improved PDF report formatting
- Improved Audit and Transaction History exports
- Standardized transaction export columns to:

    1. Item
    2. SKU
    3. Unit Price
    4. Quantity Before
    5. Quantity Changed
    6. Quantity After
    7. Date/Time (UTC)
    8. Transaction Type
    9. Notes

- Added Philippine Peso formatting for monetary values

  Example:

  `₱1,250,000.00`

- Added thousands separators to quantity values

  Example:

  `125,000`

- Quantity changes now display their direction clearly

  Examples:

  `+5,000`

  `-2,500`

## Export Styling

- Created transactions use green text
- Dispense transactions use red text
- Positive quantity changes use green text
- Negative quantity changes use red text
- Quantity After receives a red warning background when stock reaches `0`
- Removed unnecessary background highlighting from Transaction Type and Quantity Changed

## Compatibility

- CSV import support remains available for compatible inventory files
- Existing database and inventory data remain compatible
- Existing PDF reporting remains supported
- Existing backup and restore functionality remains supported

## Internal Improvements

- Improved export formatting consistency
- Improved report readability
- Improved transaction history presentation
- General code and UI cleanup related to the v2.1.0 overhaul