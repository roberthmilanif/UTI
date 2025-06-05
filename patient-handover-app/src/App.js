import React, { useContext } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import './App.css';
import NavigationBar from './components/NavigationBar/NavigationBar';
import PatientList from './components/PatientList/PatientList';
import PatientView from './components/PatientView/PatientView';
import PatientForm from './components/PatientForm/PatientForm';
import { PatientContext } from './contexts/PatientContext';

function App() {
  const { selectedPatient, setSelectedPatientId } = useContext(PatientContext);

  // This component will handle the layout for the main page
  const MainLayout = () => (
    <div className="main-layout">
      <div className="list-column">
        <PatientList />
      </div>
      <div className="view-column">
        <PatientView />
      </div>
    </div>
  );

  // This component will handle the layout for the add/edit form page
  // It ensures that when navigating to /add-patient, no patient is selected for editing
  const AddPatientLayout = () => {
    // Deselect any patient when navigating to add form
    React.useEffect(() => {
        setSelectedPatientId(null);
    }, [setSelectedPatientId]);
    return <PatientForm />;
  };

  // Separate layout for editing to ensure selectedPatient is available
  const EditPatientLayout = () => {
    // If no patient is selected, redirect to home or show a message
    // This can happen if the user directly navigates to /edit-patient without selection
    if (!selectedPatient) {
        // Optionally, you could try to load based on an ID from URL if you implement that
        // For now, redirecting or showing a message is simpler.
        // Or, PatientForm itself handles the "no selected patient" state for editing.
        // The current PatientForm is designed to switch to "Add" mode if selectedPatient is null.
        // However, for a dedicated /edit-patient route, we might want to enforce selection or redirect.
        // For now, let's assume PatientForm will show "Add Patient" if selectedPatient is null,
        // which is not ideal for an /edit-patient route.
        // A better approach for /edit-patient would be to ensure a patient is selected or load by ID.
        // Let's keep it simple: if /edit-patient is hit and no one is selected, it will behave like "add".
        // The navigation to /edit-patient should ideally only happen when a patient *is* selected.
    }
    return <PatientForm />;
  };


  return (
    <div className="App">
      <NavigationBar />
      <div className="content-area">
        <Routes>
          <Route path="/" element={<MainLayout />} />
          <Route path="/patients" element={<Navigate replace to="/" />} />
          <Route path="/add-patient" element={<AddPatientLayout />} />
          {/*
            The /edit-patient route will render PatientForm.
            PatientForm's useEffect hook will check for a selectedPatient from context.
            If a patient is selected, it populates the form for editing.
            If not, it stays in "add new" mode.
            This means direct navigation to /edit-patient without a selection context
            will effectively show the "Add New Patient" form.
            Proper handling for /edit/:id would be a more robust solution for direct linking.
          */}
          <Route path="/edit-patient" element={<EditPatientLayout />} />
          {/* Fallback for unknown routes */}
          <Route path="*" element={<Navigate replace to="/" />} />
        </Routes>
      </div>
    </div>
  );
}

export default App;
